//
//  MoreCommentsBatching.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 12/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

/**
 Takes a flat list of comments and creates a 2D list, with each subarray having up to 100 elements each.
 This allows the maximum number of 'more comments' to be fetched from the Reddit API in a single request.
 */
func batch(comments: [Either<Comment, MoreComments>], maximum: Int) -> [[MoreComments]] {
    // Must be 100 according to Reddit API Docs here for requesting more children:
    // https://www.reddit.com/dev/api/#GET_api_morechildren
    let maximumChildrenCount = 100
    
    let comments = comments
        .flatMap { $0.other }
        .sorted { $0.children.count > $1.children.count }
    
    var batches: [[MoreComments]] = []
    var current: [MoreComments] = []
    
    for (index, comment) in comments.enumerated() {
        current.append(comment)
        guard index + 1 < comments.endIndex else {
            batches.append(current)
            return batches
        }
        let currentChildrenCount = current.reduce(0) { $0 + $1.children.count }
        let nextChildrenCount = comments[index + 1].children.count
        if currentChildrenCount + nextChildrenCount > maximumChildrenCount {
            batches.append(current)
            if batches.count >= maximum {
                return batches
            }
            current = []
        }
    }
    return batches
}
