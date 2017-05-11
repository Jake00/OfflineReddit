//
//  PostsDownloader.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

final class PostsDownloader: NSObject, ProgressReporting {
    
    let progress: Progress
    let numberOfCommentBatches: Int
    let provider: DataProviding
    let posts: [Post]
    var completionForPost: ((Post) -> Void)?
    private var remainingPosts: [Post]
    private var comments: [CommentsTask] = []
    
    private class CommentsTask {
        let post: Post
        var more: [[MoreComments]]
        let progress: Progress?
        
        init(post: Post, more: [[MoreComments]], progress: Progress?) {
            self.post = post
            self.more = more
            self.progress = progress
        }
    }
    
    init(posts: [Post], provider: DataProviding, numberOfCommentBatches: Int = 3) {
        self.posts = posts
        self.remainingPosts = posts
        self.provider = provider
        self.numberOfCommentBatches = numberOfCommentBatches
        self.progress = Progress(totalUnitCount: Int64((1 + numberOfCommentBatches) * posts.count))
        super.init()
    }
    
    func start() -> Task<[Post]> {
        /* 
         Breadth first strategy:
         1. Download each posts top level comments, marking the 'more comments' ids for step 2. The top level `progress.totalUnitCount` is updated during this step.
         2. For each post downloaded, fetch 'more comments'. Once all comments have been fetched then that post is considered completed.
         */
        return downloadNextPost()
            .continueOnSuccessWithTask(continuation: downloadNextPostsComments)
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueWith { _ in self.posts }
    }
    
    // MARK: - Downloading
    
    private func downloadNextPost() -> Task<Void> {
        guard !remainingPosts.isEmpty else { return Task(()) }
        let post = remainingPosts.removeFirst()
        return provider.getComments(for: post)
            .continueOnSuccessWithTask { _ in self.nextPostDidDownload(post) }
    }
    
    private func nextPostDidDownload(_ post: Post) -> Task<Void> {
        self.progress.completedUnitCount += 1
        post.isAvailableOffline = true
        let more = post.batchedMoreComments(maximum: numberOfCommentBatches)
        let commentsProgress: Progress? = more.isEmpty ? nil : Progress(
            totalUnitCount: Int64(more.count),
            parent: self.progress,
            pendingUnitCount: Int64(numberOfCommentBatches))
        self.progress.totalUnitCount -= Int64(numberOfCommentBatches - more.count)
        let task = CommentsTask(post: post, more: more, progress: commentsProgress)
        self.comments.append(task)
        return self.downloadNextPost()
    }
    
    private func downloadNextPostsComments() -> Task<Void> {
        guard !comments.isEmpty else {
            return Task(())
        }
        let next = self.comments.removeFirst()
        
        func downloadNextCommentBatch() -> Task<Void> {
            guard !next.more.isEmpty else { return Task(()) }
            let comments = next.more.removeFirst()
            return provider.getMoreComments(using: comments, post: next.post)
                .continueOnSuccessWithTask { _ in
                    next.progress?.completedUnitCount += 1
                    return downloadNextCommentBatch()
            }
        }
        
        return downloadNextCommentBatch().continueOnSuccessWithTask { _ -> Task<Void> in
            self.completionForPost?(next.post)
            if let progress = next.progress {
                progress.completedUnitCount = progress.totalUnitCount
            }
            return self.downloadNextPostsComments()
        }
    }
}
