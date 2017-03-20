//
//  MoreComments.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class MoreComments: NSManagedObject {
    
    @NSManaged var id: String
    @NSManaged var parentId: String?
    @NSManaged var depth: Int64
    @NSManaged var count: Int64
    @NSManaged var children: [String]
    @NSManaged var parentComment: Comment?
    @NSManaged var parentPost: Post?
}

extension MoreComments {
    
    static func fetchRequest(predicate: NSPredicate) -> NSFetchRequest<MoreComments> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<MoreComments>
    }
    
    func update(json: JSON) {
        depth = (json["depth"] as? Int).map(Int64.init) ?? 0
        count = (json["count"] as? Int).map(Int64.init) ?? 0
        children = json["children"] as? [String] ?? []
        parentId = json["parent_id"] as? String
    }
    
    var owningPost: Post? {
        return parentPost ?? parentComment?.owningPost
    }
}

extension MoreComments: Identifiable { }
