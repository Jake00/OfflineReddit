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
        return Sort.best.comparitor(lhs, rhs)
    }
    
    enum Sort {
        case best
        case top
        case new
        case old
        case controversial
        
        static let all: [Sort] = [.best, .top, .new, .old, .controversial]
        
        var displayName: String {
            switch self {
            case .best: return SharedText.sortBest
            case .top: return SharedText.sortTop
            case .new: return SharedText.sortNew
            case .old: return SharedText.sortOld
            case .controversial: return SharedText.sortControversial
            }
        }
        
        var descriptor: NSSortDescriptor {
            switch self {
            case .best: return NSSortDescriptor(key: "orderBest", ascending: false)
            case .top: return NSSortDescriptor(key: "score", ascending: false)
            case .new: return NSSortDescriptor(key: "created", ascending: true)
            case .old: return NSSortDescriptor(key: "created", ascending: false)
            case .controversial: return NSSortDescriptor(key: "orderControversial", ascending: false)
            }
        }
        
        var comparitor: ((Comment, Comment) -> Bool) {
            switch self {
            case .best: return { compare($0, $1) { $0.orderBest > $1.orderBest }}
            case .top: return { compare($0, $1) { $0.score > $1.score }}
            case .new: return { compare($0, $1) { $0.created > $1.created }}
            case .old: return { compare($0, $1) { $0.created < $1.created }}
            case .controversial: return { compare($0, $1) { $0.orderControversial > $1.orderControversial }}
            }
        }
    }
    
    func updateSortingScores() {
        orderBest = Sorts.confidence(ups, downs)
        orderControversial = Sorts.controversy(ups, downs)
    }
}

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

extension Collection where Iterator.Element == Comment {
    
    func sorted(by sorting: Comment.Sort) -> [Comment] {
        return sorted(by: sorting.comparitor)
    }
    
    func updateSortingScores() {
        forEach { $0.updateSortingScores() }
    }
}
