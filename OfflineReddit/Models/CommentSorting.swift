//
//  CommentSorting.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 24/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

extension Comment: Comparable {
    
    static func < (lhs: Comment, rhs: Comment) -> Bool {
        return Sort.top.comparitor(lhs, rhs, .none)
    }
    
    enum Sort {
        case top
        case worst
        case new
        case old
        case controversial
        
        static let all: [Sort] = [.top, .worst, .new, .old, .controversial]
        
        var displayName: String {
            switch self {
            case .top:   return SharedText.sortTop
            case .worst: return SharedText.sortWorst
            case .new:   return SharedText.sortNew
            case .old:   return SharedText.sortOld
            case .controversial: return SharedText.sortControversial
            }
        }
        
        var descriptor: NSSortDescriptor? {
            switch self {
            case .top:   return NSSortDescriptor(key: "score", ascending: false)
            case .worst: return NSSortDescriptor(key: "score", ascending: true)
            case .new:   return NSSortDescriptor(key: "created", ascending: true)
            case .old:   return NSSortDescriptor(key: "created", ascending: false)
            case .controversial: return nil
            }
        }
        
        var comparitor: ((Comment, Comment, MoreCommentsSide) -> Bool) {
            return { compare($0, $1, $2, { Sort._compare(self, $0, $1) }) }
        }
        
        private static func _compare(_ sort: Sort?, _ lhs: Comment, _ rhs: Comment) -> Bool {
            switch sort {
            case .top?:
                return lhs.score != rhs.score
                    ? lhs.score > rhs.score
                    : _compare(.old, lhs, rhs)
            case .worst?:
                return lhs.score != rhs.score
                    ? lhs.score < rhs.score
                    : _compare(.old, lhs, rhs)
            case .new?:
                return lhs.created != rhs.created
                    ? lhs.created > rhs.created
                    : _compare(nil, lhs, rhs)
            case .old?:
                return lhs.created != rhs.created
                    ? lhs.created < rhs.created
                    : _compare(nil, lhs, rhs)
            case .controversial?:
                return controversyEstimate(lhs, rhs)
                    ?? _compare(nil, lhs, rhs)
            case nil:
                if let lhsAuthor = lhs.author, let rhsAuthor = rhs.author, lhsAuthor != rhsAuthor {
                    return lhsAuthor < rhsAuthor
                } else if let lhsBody = lhs.body, let rhsBody = rhs.body, lhsBody != rhsBody {
                    return lhsBody < rhsBody
                }
                return false
            }
        }
    }
}

enum MoreCommentsSide {
    case none, left, right, both
}

/// Compares two comments which may have different parent comments
/// ie. they may not be in the same tree.
/// This allows sorting an arbitrary list of comments where ordering 
/// will be preserved from parents to children.
private func compare(
    _ lhs: Comment,
    _ rhs: Comment,
    _ moreCommentsSide: MoreCommentsSide,
    _ comparison: (Comment, Comment) -> Bool
    ) -> Bool {
    
    if lhs.parent == rhs.parent {
        return comparison(lhs, rhs)
    }
    let lhsHierarchy = lhs.hierarchy
    let rhsHierarchy = rhs.hierarchy
    
    for (index, lhsComment) in lhsHierarchy.enumerated()
        where index < rhsHierarchy.endIndex {
            let rhsComment = rhsHierarchy[index]
            if lhsComment != rhsComment {
                return comparison(lhsComment, rhsComment)
            }
    }
    switch moreCommentsSide {
    case .none:  return rhsHierarchy.contains(lhs) || !lhsHierarchy.contains(rhs)
    case .both:  return lhs.depth > rhs.depth
    case .left:  return false
    case .right: return true
    }
}

fileprivate extension Comment {
    
    var hierarchy: [Comment] {
        var hierarchy: [Comment] = []
        buildHierarchy(accumulator: &hierarchy)
        return hierarchy
    }
    
    private func buildHierarchy(accumulator: inout [Comment]) {
        accumulator.insert(self, at: 0)
        parent?.buildHierarchy(accumulator: &accumulator)
    }
}

// swiftlint:disable line_length

/// We can't get the total upvotes and downvotes (Reddit only
/// exposes a single 'score', with upvotes=score and downvotes=0)
/// https://github.com/reddit/reddit/blob/dbcf37afe2c5f5dd19f99b8a3484fc69eb27fcd5/r2/r2/lib/jsontemplates.py#L817
/// So this estimates by putting the score closest to 0 at the top 
/// (equal number of upvotes and downvotes).
private func controversyEstimate(_ lhs: Comment, _ rhs: Comment) -> Bool? {
    switch (lhs.isControversial, rhs.isControversial) {
    case (false, false):
        return lhs.score != rhs.score
            ? lhs.score < rhs.score
            : nil
    case (true, true):
        return lhs.score != rhs.score
            ? abs(lhs.score) < abs(rhs.score)
            : nil
    default:
        return lhs.isControversial
    }
}

extension Collection where Iterator.Element == Comment {
    
    // Allows the syntax `comments.sorted(by: .top)`
    func sorted(by sorting: Comment.Sort) -> [Comment] {
        let comparitor = sorting.comparitor
        return sorted { comparitor($0, $1, .none) }
    }
}
