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
        return best(lhs: lhs, rhs: rhs)
    }
    
    enum Sort {
        case best
        case top
        
        static let all: [Sort] = [.best, .top]
        
        var displayName: String {
            switch self {
            case .best: return SharedText.best
            case .top: return SharedText.top
            }
        }
        
        var descriptor: NSSortDescriptor {
            switch self {
            case .best: return NSSortDescriptor(key: "orderBest", ascending: false)
            case .top: return NSSortDescriptor(key: "score", ascending: false)
            }
        }
    }
    
    func updateOrderBest() {
        orderBest = confidenceScore
    }
    
    var confidenceScore: Double {
        /* 
         Taken from Reddit's confidence sort here:
         https://github.com/reddit/reddit/blob/52728820cfc60a9a7be47272ff7fb1031c2710c7/r2/r2/lib/db/_sorts.pyx#L70
         They in turn are using this algorithm here:
         http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
         Using the same variable names as the algorthm-
         p is the number of positive ratings,
         n is the total number of ratings,
         confidence refers to the statistical confidence level: pick 0.95 to have a 95% chance that your lower bound is correct, 0.975 to have a 97.5% chance, etc. The z-score in this function never changes, so if you don't have a statistics package handy or if performance is an issue you can always hard-code a value here for z. (Use 1.96 for a confidence level of 0.95.)
         */
        let n = Double(ups + downs)
        if n == 0 {
            return 0
        }
        let z = 1.281551565545 // 80% confidence
        let p = Double(ups) / n
        let left: Double = p + 1 / (2 * n) * z * z
        let right: Double = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n))
        let under: Double = 1 + 1 / n * z * z
        return (left - right) / under
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

/// This named is to enable the syntax `comments.sorted(by: best)`
private func best(lhs: Comment, rhs: Comment) -> Bool {
    return compare(lhs, rhs) { $0.orderBest > $1.orderBest }
}

/// This named is to enable the syntax `comments.sorted(by: top)`
private func top(lhs: Comment, rhs: Comment) -> Bool {
    return compare(lhs, rhs) { $0.score > $1.score }
}

extension Collection where Iterator.Element == Comment {
    
    func sorted(by sorting: Comment.Sort) -> [Comment] {
        switch sorting {
        case .best: return sorted(by: best)
        case .top: return sorted(by: top)
        }
    }
}
