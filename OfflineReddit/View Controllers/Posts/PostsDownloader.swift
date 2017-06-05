//
//  PostsDownloader.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift
import CoreData

final class PostsDownloader: NSObject, ProgressReporting {
    
    var posts: [Post] = []
    let progress: Progress
    let numberOfCommentBatches: Int
    let remote: RemoteDataProviding
    let commentsSort: Comment.Sort
    var completionForPost: ((Post) -> Void)?
    private var remainingPosts: [Post] = []
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
    
    init(remote: RemoteDataProviding, commentsSort: Comment.Sort, numberOfCommentBatches: Int = 3) {
        self.remote = remote
        self.commentsSort = commentsSort
        self.numberOfCommentBatches = numberOfCommentBatches
        self.progress = Progress()
        super.init()
    }
    
    func start() -> Task<[Post]> {
        /* 
         Breadth first strategy:
         1. Download each posts top level comments, marking the 'more comments' ids for step 2. The top level `progress.totalUnitCount` is updated during this step.
         2. For each post downloaded, fetch 'more comments'. Once all comments have been fetched then that post is considered completed.
         */
        remainingPosts = posts
        progress.totalUnitCount = Int64((1 + numberOfCommentBatches) * posts.count)
        return downloadNextPost()
            .continueOnSuccessWithTask(.immediate, continuation: downloadNextPostsComments)
            .continueOnSuccessWithTask(.immediate) { Task<Void>.withDelay(1) }
            .continueWith(.immediate) { _ in self.posts }
    }
    
    // MARK: - Downloading
    
    private func downloadNextPost() -> Task<Void> {
        guard !remainingPosts.isEmpty else { return Task(()) }
        let post = remainingPosts.removeFirst()
        return remote.getComments(for: post, sortedBy: commentsSort)
            .continueOnSuccessWithTask(.immediate) { _ in self.nextPostDidDownload(post) }
    }
    
    private func nextPostDidDownload(_ post: Post) -> Task<Void> {
        self.progress.completedUnitCount += 1
        post.isAvailableOffline = true
        let more = batch(moreComments: post.allMoreComments, sort: commentsSort, maximum: numberOfCommentBatches)
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
            return remote.getMoreComments(using: comments, post: next.post, sortedBy: commentsSort)
                .continueOnSuccessWithTask(.immediate) { _ in
                    next.progress?.completedUnitCount += 1
                    return downloadNextCommentBatch()
            }
        }
        
        return downloadNextCommentBatch().continueOnSuccessWithTask(.immediate) { _ -> Task<Void> in
            if let completionForPost = self.completionForPost {
                DispatchQueue.main.async { completionForPost(next.post) }
            }
            if let progress = next.progress {
                progress.completedUnitCount = progress.totalUnitCount
            }
            return self.downloadNextPostsComments()
        }
    }
}
