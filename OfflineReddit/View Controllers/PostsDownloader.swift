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
    var completionForPost: ((Post) -> Void)?
    private(set) var error: Error?
    private var posts: [Post]
    private var comments: [Comments] = []
    
    var numberOfCommentBatches = 3 {
        didSet { updateTotalUnitCount() }
    }
    
    private class Comments {
        let post: Post
        var more: [[MoreComments]]
        let progress: Progress
        
        init(post: Post, more: [[MoreComments]], progress: Progress) {
            self.post = post
            self.more = more
            self.progress = progress
        }
    }
    
    init(posts: [Post]) {
        self.posts = posts
        self.progress = Progress()
        super.init()
        updateTotalUnitCount()
    }
    
    private func updateTotalUnitCount() {
        progress.totalUnitCount = Int64((1 + posts.count) * numberOfCommentBatches)
    }
    
    override func main() {
        /* 
         Strategy:
         1. Download all posts first, one by one. By doing this first we tally how many child progress units are needed sooner to get a more accurate total unit count.
         2. For each post downloaded, fetch comments. Once all comments have been fetched then that post is considered completed.
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
    
    private func downloadNextPost() -> Task<Void> {
        guard !posts.isEmpty else { return Task(()) }
        let post = posts.removeFirst()
        return APIClient.shared.getComments(for: post)
            .continueOnSuccessWithTask { _ -> Task<Void> in
                self.progress.completedUnitCount += 1
                post.isAvailableOffline = true
                let more = post.batchedMoreComments(maximum: self.numberOfCommentBatches)
                let commentsProgress = Progress(totalUnitCount: Int64(more.count), parent: self.progress, pendingUnitCount: Int64(self.numberOfCommentBatches))
                let comments = Comments(post: post, more: more, progress: commentsProgress)
                self.comments.append(comments)
                return self.downloadNextPost()
        }
    }
    
    private func downloadNextPostsComments() -> Task<Void> {
        guard !comments.isEmpty else {
            return Task(())
        }
        let next = self.comments.removeFirst()
        
        func downloadNextCommentBatch() -> Task<Void> {
            guard !next.more.isEmpty else { return Task(()) }
            let comments = next.more.removeFirst()
            return APIClient.shared.getMoreComments(using: comments, post: next.post)
                .continueOnSuccessWithTask { _ in
                    next.progress.completedUnitCount += 1
                    return downloadNextCommentBatch()
            }
        }
        
        return downloadNextCommentBatch().continueOnSuccessWithTask { _ -> Task<Void> in
            self.completionForPost?(next.post)
            return self.downloadNextPostsComments()
        }
    }
}
