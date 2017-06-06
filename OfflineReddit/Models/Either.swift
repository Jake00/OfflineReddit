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

extension Either: CustomDebugStringConvertible {
    
    var debugDescription: String {
        switch self {
        case .first(let a):
            return "\(type(of: self)).first: \(a)"
        case .other(let b):
            return "\(type(of: self)).other: \(b)"
        }
    }
}

// MARK: - Equality

/// Since Swift does not yet support conditional protocol conformance
/// ie. `extension Either: Equatable where A: Equatable, B: Equatable`
/// this workaround is necessary to support equatable conformance for diffing.
/// Usage: `Either<A, B>.equatable == Either<A, B>.equatable`
struct EitherEquatable<A: Equatable, B: Equatable>: Equatable {
    
    let wrapped: Either<A, B>
    
    static func == (lhs: EitherEquatable, rhs: EitherEquatable) -> Bool {
        switch (lhs.wrapped, rhs.wrapped) {
        case let (.first(a1), .first(a2)): return a1 == a2
        case let (.other(b1), .other(b2)): return b1 == b2
        default: return false
        }
    }
}

extension Either where A: Equatable, B: Equatable {
    var equatable: EitherEquatable<A, B> {
        return EitherEquatable(wrapped: self)
    }
}
