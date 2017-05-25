//
//  CommentSorting.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 24/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

extension Comment: Comparable {
    
    static func < (lhs: Comment, rhs: Comment) -> Bool {
        return Sort.top.comparitor(lhs, rhs)
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
        
        var comparitor: ((Comment, Comment) -> Bool) {
            switch self {
            case .top:   return { compare($0, $1) { $0.score > $1.score }}
            case .worst: return { compare($0, $1) { $0.score < $1.score }}
            case .new:   return { compare($0, $1) { $0.created > $1.created }}
            case .old:   return { compare($0, $1) { $0.created < $1.created }}
            case .controversial: return contoversyEstimate
            }
        }
    }
    
    func updateSortingScores() {
        
    }
}

/// Compares two comments which may have different parent comments ie. they may not be in the same tree.
/// This allows sorting an arbitrary list of comments where ordering will be preserved from parents to children.
private func compare(_ lhs: Comment, _ rhs: Comment, _ comparison: (Comment, Comment) -> Bool) -> Bool {
    if lhs.parent == rhs.parent {
        return comparison(lhs, rhs)
    }
    let lhsHierarchy = lhs.hierarchy
    let rhsHierarchy = rhs.hierarchy
    
    for (index, lhsComment) in lhsHierarchy.enumerated() where index < rhsHierarchy.endIndex {
        let rhsComment = rhsHierarchy[index]
        if lhsComment != rhsComment {
            return comparison(lhsComment, rhsComment)
        }
    }
    return rhsHierarchy.contains(lhs) || !lhsHierarchy.contains(rhs)
}

/// We can't get the total upvotes and downvotes (Reddit only exposes a single 'score', with upvotes=score and downvotes=0)
/// https://github.com/reddit/reddit/blob/dbcf37afe2c5f5dd19f99b8a3484fc69eb27fcd5/r2/r2/lib/jsontemplates.py#L817
/// So this estimates by putting the score closest to 0 at the top (equal number of upvotes and downvotes).
private func contoversyEstimate(lhs: Comment, rhs: Comment) -> Bool {
    switch (lhs.isControversial, rhs.isControversial) {
    case (false, false): return compare(lhs, rhs) { $0.score < $1.score }
    case (true, true): return compare(lhs, rhs) { abs($0.score) < abs($1.score) }
    default: return lhs.isControversial
    }
}

extension Collection where Iterator.Element == Comment {
    
    func sorted(by sorting: Comment.Sort) -> [Comment] {
        return sorted(by: sorting.comparitor)
    }
    
    func updateSortingScores() {
        forEach { $0.updateSortingScores() }
    }
}
