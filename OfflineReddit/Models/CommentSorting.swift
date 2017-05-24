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
    
    func generateBestScore() -> Double {
        /* 
         Taken from the Ruby example here
         http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
         
         def ci_lower_bound(pos, n, confidence)
            if n == 0
                return 0
            end
            z = Statistics2.pnormaldist(1-(1-confidence)/2)
            phat = 1.0*pos/n
            (phat + z*z/(2*n) - z * Math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)
         end
         
         pos is the number of positive ratings,
         n is the total number of ratings, 
         confidence refers to the statistical confidence level: pick 0.95 to have a 95% chance that your lower bound is correct, 0.975 to have a 97.5% chance, etc. The z-score in this function never changes, so if you don't have a statistics package handy or if performance is an issue you can always hard-code a value here for z. (Use 1.96 for a confidence level of 0.95.)
         */
        if numberOfVotes == 0 {
            return 0
        }
        let n = Double(numberOfVotes)
        let z = 1.96
        let phat = Double(ups) / n
        
        /*
         (phat + z*z/(2*n) - z * Math.sqrt((phat*(1-phat)+z*z/(4*n))/n))/(1+z*z/n)
         'expression was too complex to be solved in reasonable time; consider breaking up the expression into distinct sub-expressions'
         */
        let sqrtDividend: Double = phat * (1 - phat) + z * z / (4 * n)
        let dividend: Double = phat + z * z / (2 * n) - z * sqrt(sqrtDividend / n)
        let divisor: Double = 1 + z * z / n
        return dividend / divisor
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
