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
    @NSManaged var isSelected: Bool
    @NSManaged var posts: Set<Post>
}

extension Subreddit {
    
    @nonobjc static func fetchRequest(predicate: NSPredicate? = nil) -> NSFetchRequest<Subreddit> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<Subreddit>
    }
    
    static func create(in context: NSManagedObjectContext, name: String) -> Subreddit {
        let subreddit: Subreddit = create(in: context)
        subreddit.name = name
        return subreddit
    }
    
    static func insertDefaults(into context: NSManagedObjectContext) -> [Subreddit] {
        return defaults.map { create(in: context, name: $0) }
    }
    
    static var defaults: [String] {
        return ["announcements", "Art", "AskReddit", "askscience", "aww", "blog", "books", "creepy", "dataisbeautiful", "DIY", "Documentaries", "EarthPorn", "explainlikeimfive", "food", "funny", "Futurology", "gadgets", "gaming", "GetMotivated", "gifs", "history", "IAmA", "InternetIsBeautiful", "Jokes", "LifeProTips", "listentothis", "mildlyinteresting", "movies", "Music", "news", "nosleep", "nottheonion", "OldSchoolCool", "personalfinance", "philosophy", "photoshopbattles", "pics", "science", "Showerthoughts", "space", "sports", "television", "tifu", "todayilearned", "TwoXChromosomes", "UpliftingNews", "videos", "worldnews", "WritingPrompts"]
    }
}
