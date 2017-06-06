//
//  CommentsDownloader.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 12/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation
import BoltsSwift

final class CommentsDownloader: NSObject, ProgressReporting {
    
    let progress: Progress
    let post: Post
    let remote: RemoteDataProviding
    let comments: [[MoreComments]]
    let sort: Comment.Sort
    private(set) var remaining: [[MoreComments]]
    
    init(post: Post, comments: [MoreComments], remote: RemoteDataProviding, sort: Comment.Sort, numberOfCommentBatches: Int = 5) {
        self.post = post
        self.remote = remote
        self.sort = sort
        let batches = batch(moreComments: comments, sort: sort, maximum: numberOfCommentBatches)
        self.comments = batches
        self.remaining = batches
        self.progress = Progress(totalUnitCount: Int64(batches.count))
        super.init()
    }
    
    func start() -> Task<Void> {
        return downloadNext().continueOnSuccessWithTask { Task<Void>.withDelay(1) }
    }
    
    private func downloadNext() -> Task<Void> {
        guard !remaining.isEmpty else { return Task(()) }
        return remote.getMoreComments(using: remaining.removeFirst(), post: post, sortedBy: sort)
            .continueOnSuccessWithTask { _ in
                self.progress.completedUnitCount += 1
                return self.downloadNext()
        }
    }
}
