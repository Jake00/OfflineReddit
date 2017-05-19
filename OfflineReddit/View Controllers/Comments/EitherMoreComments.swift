//
//  EitherMoreComments.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 9/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

extension Either where A == Comment, B == MoreComments {
    
    var depth: Int64 {
        switch self {
        case .first(let a): return a.depth
        case .other(let b): return b.depth
        }
    }
    
    var isExpanded: Bool {
        switch self {
        case .first(let a): return a.isExpanded
        case .other: return true
        }
    }
}

func == (lhs: Either<Comment, MoreComments>, rhs: Either<Comment, MoreComments>) -> Bool {
    switch (lhs, rhs) {
    case let (.first(a), .first(b)): return a == b
    case let (.other(a), .other(b)): return a == b
    default: return false
    }
}
