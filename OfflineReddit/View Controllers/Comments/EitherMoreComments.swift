//
//  EitherMoreComments.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 9/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

// MARK: Equality

func == (lhs: Either<Comment, MoreComments>, rhs: Either<Comment, MoreComments>) -> Bool {
    switch (lhs, rhs) {
    case let (.first(a), .first(b)): return a == b
    case let (.other(a), .other(b)): return a == b
    default: return false
    }
}

func == (lhs: Either<Comment, MoreComments>, rhs: MoreComments) -> Bool {
    return lhs.other == rhs
}

func == (lhs: Either<Comment, MoreComments>, rhs: Comment) -> Bool {
    return lhs.first == rhs
}

// MARK: - Comparisons

func < (lhs: Either<Comment, MoreComments>, rhs: Either<Comment, MoreComments>) -> Bool {
    return compare(lhs, rhs, Comment.Sort.top.comparitor)
}

func compare(
    _ lhs: Either<Comment, MoreComments>,
    _ rhs: Either<Comment, MoreComments>,
    _ comparison: (Comment, Comment, MoreCommentsSide) -> Bool
    ) -> Bool {
    
    switch (lhs, rhs) {
    case let (.first(lhs), .first(rhs)):
        return comparison(lhs, rhs, [])
        
    case let (.first(lhs), .other(more)):
        guard let rhs = more.parentComment else { return true }
        return lhs == rhs || comparison(lhs, rhs, .right)
        
    case let (.other(more), .first(rhs)):
        guard let lhs = more.parentComment else { return false }
        return lhs != rhs && comparison(lhs, rhs, .left)
        
    case let (.other(lhsMore), .other(rhsMore)):
        guard let lhs = lhsMore.parentComment, let rhs = rhsMore.parentComment else {
            return lhsMore.parentComment != nil
        }
        return lhs != rhs && comparison(lhs, rhs, [.left, .right])
    }
}

extension Collection where Iterator.Element == Either<Comment, MoreComments> {
    
    func sorted(by sorting: Comment.Sort) -> [Either<Comment, MoreComments>] {
        let comparitor = sorting.comparitor
        return sorted { compare($0, $1, comparitor) }
    }
}
