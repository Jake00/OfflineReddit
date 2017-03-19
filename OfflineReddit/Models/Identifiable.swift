//
//  Identifiable.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation

protocol Identifiable: Hashable {
    var id: String { get set }
}

extension Identifiable {
    var hashValue: Int {
        return id.hashValue
    }
}

func == <T: Identifiable>(lhs: T, rhs: T) -> Bool {
    return lhs.id == rhs.id
}
