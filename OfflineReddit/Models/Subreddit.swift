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
