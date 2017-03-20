//
//  Either.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

enum Either<A, B> {
    case first(A)
    case other(B)
    
    var first: A? {
        switch self {
        case .first(let a): return a
        default: return nil
        }
    }
    
    var other: B? {
        switch self {
        case .other(let b): return b
        default: return nil
        }
    }
}
