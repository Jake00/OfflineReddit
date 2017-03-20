//
//  Subreddit.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class Subreddit: NSManagedObject {
    
    @NSManaged var name: String
    @NSManaged var posts: Set<Post>
}

extension Subreddit {
    
    static func fetchRequest(predicate: NSPredicate) -> NSFetchRequest<Subreddit> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<Subreddit>
    }
    
    static func create(in context: NSManagedObjectContext, name: String) -> Subreddit {
        let subreddit: Subreddit = create(in: context)
        subreddit.name = name
        return subreddit
    }
}
