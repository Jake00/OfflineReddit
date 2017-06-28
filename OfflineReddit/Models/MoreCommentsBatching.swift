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
func batch(moreComments: [MoreComments], sort: Comment.Sort, maximum: Int) -> [[MoreComments]] {
    // Must be 100 according to Reddit API Docs here for requesting more children:
    // https://www.reddit.com/dev/api/#GET_api_morechildren
    let maximumChildrenCount = 100
    var batches: [[MoreComments]] = []
    var current: [MoreComments] = []
    
    for (index, comment) in moreComments.sorted(by: sort).enumerated() {
        current.append(comment)
        guard index + 1 < moreComments.endIndex else {
            batches.append(current)
            return batches
        }
        let currentChildrenCount = current.reduce(0) { $0 + $1.children.count }
        let nextChildrenCount = moreComments[index + 1].children.count
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

func batch(comments: [Either<Comment, MoreComments>], sort: Comment.Sort, maximum: Int) -> [[MoreComments]] {
    return batch(moreComments: comments.flatMap { $0.other }, sort: sort, maximum: maximum)
}

// MARK: - Sorting

fileprivate extension Collection where Iterator.Element == MoreComments {
    
    func sorted(by sorting: Comment.Sort) -> [MoreComments] {
        return sorted(by: sorting.moreCommentsComparitor)
    }
}

fileprivate extension Comment.Sort {
    
    var moreCommentsComparitor: (MoreComments, MoreComments) -> Bool {
        let now = Date()
        switch self {
        case .top:   return { compare($0, $1) { score($0) > score($1) }}
        case .worst: return { compare($0, $1) { score($0) < score($1) }}
        case .new:   return { compare($0, $1) { newest($0, now) < newest($1, now) }}
        case .old:   return { compare($0, $1) { newest($0, now) > newest($1, now) }}
        case .controversial: return { compare($0, $1) { controversy($0) > controversy($1) }}
        }
    }
}

/// Sort strategy for picking the top comments to expand:
/// 1. Take the top level comments first (`parentPost != nil`), then
/// 2. Sort using the provided comparitor.
private func compare(
    _ lhs: MoreComments,
    _ rhs: MoreComments,
    _ comparison: (MoreComments, MoreComments) -> Bool
    ) -> Bool {
    let bothHaveParentsOrNone = (lhs.parentPost == nil) == (rhs.parentPost == nil)
    return bothHaveParentsOrNone ? comparison(lhs, rhs) : lhs.parentPost != nil
}

private func score(_ more: MoreComments) -> Int64 {
    return accumulate(more) { $0.score }
}

private func newest(_ more: MoreComments, _ now: Date) -> TimeInterval {
    return more.parentComment?.created.timeIntervalSince(now) ?? 0
}

private func controversy(_ more: MoreComments) -> Int64 {
    return accumulate(more) {
        var controversality: Int64 = 100000 - $0.score
        if $0.isControversial {
            controversality += 100000
        }
        return controversality
    }
}

// MARK: - Accumulating scores

private protocol Accumuatable: ExpressibleByIntegerLiteral {
    static func += (lhs: inout Self, rhs: Self)
}
extension Int64: Accumuatable { }
extension TimeInterval: Accumuatable { }

private func accumulate<T: Accumuatable>(_ more: MoreComments, accumulator: (Comment) -> T) -> T {
    var value: T = 0
    var next = more.parentComment
    while let current = next {
        value += accumulator(current)
        next = current.parent
    }
    return value
}
