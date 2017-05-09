//
//  PostsDownloader.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

final class PostsDownloader: AsyncOperation, ProgressReporting {
    
    let progress: Progress
    let numberOfCommentBatches: Int
    let provider: DataProviding
    var completionForPost: ((Post) -> Void)?
    private(set) var error: Error?
    private var posts: [Post]
    private var comments: [Comments] = []
    
    private class Comments {
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
        self.provider = provider
        self.numberOfCommentBatches = numberOfCommentBatches
        self.progress = Progress(totalUnitCount: Int64((1 + numberOfCommentBatches) * posts.count))
        super.init()
    }
    
    // MARK: - Operation
    
    override func main() {
        /* 
         Strategy:
         1. Download all posts first, one by one. By doing this first we tally how many child progress units are needed sooner to get a more accurate total unit count.
         2. For each post downloaded, fetch 'more comments'. Once all comments have been fetched then that post is considered completed.
         */
        downloadNextPost()
            .continueOnSuccessWithTask(continuation: downloadNextPostsComments)
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueOnErrorWith { self.error = $0 }
            .continueWith { _ in self.complete() }
    }
    
    override func complete() {
        super.complete()
        completionForPost = nil
    }
    
    // MARK: - Downloading
    
    private func downloadNextPost() -> Task<Void> {
        guard !posts.isEmpty else { return Task(()) }
        let post = posts.removeFirst()
        return provider.getComments(for: post)
            .continueOnSuccessWithTask { _ in self.nextPostDidDownload(post) }
    }
    
    private func nextPostDidDownload(_ post: Post) -> Task<Void> {
        self.progress.completedUnitCount += 1
        post.isAvailableOffline = true
        let more = post.batchedMoreComments(maximum: self.numberOfCommentBatches)
        let commentsProgress: Progress?
        if more.isEmpty {
            commentsProgress = nil
            self.progress.totalUnitCount -= Int64(self.numberOfCommentBatches)
        } else {
            commentsProgress = Progress(
                totalUnitCount: Int64(more.count),
                parent: self.progress,
                pendingUnitCount: Int64(self.numberOfCommentBatches))
        }
        let comments = Comments(post: post, more: more, progress: commentsProgress)
        self.comments.append(comments)
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
