//
//  Identifiable.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation
import CoreData

protocol Identifiable: Hashable {
    var id: String { get set }
    static func id(from json: JSON) -> (String, JSON)?
}

extension Identifiable {
    
    var hashValue: Int {
        return id.hashValue
    }
    
    static func id(from json: JSON) -> (String, JSON)? {
        let data = json["data"] as? JSON ?? json
        if let id = data["name"] as? String {
            return (id, data)
        }
        return nil
    }
}

extension Identifiable where Self: NSManagedObject {
    
    static func create(in context: NSManagedObjectContext, id: String) -> Self {
        var obj: Self = create(in: context)
        obj.id = id
        return obj
    }
}

func == <T: Identifiable>(lhs: T, rhs: T) -> Bool {
    return lhs.id == rhs.id
}
