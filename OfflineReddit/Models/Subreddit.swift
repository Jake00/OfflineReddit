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
    @NSManaged var rawContentType: Int64
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
        return Defaults.subreddits.map { name, contentType in
            let subreddit = create(in: context, name: name)
            subreddit.contentType = contentType
            return subreddit
        }
    }
    
    enum ContentType: Int64 {
        case unknown, text, multimedia
        
        var displayName: String {
            switch self {
            case .unknown:    return SharedText.subredditContentTypeUnknown
            case .text:       return SharedText.subredditContentTypeText
            case .multimedia: return SharedText.subredditContentTypeMultimedia
            }
        }
    }
    
    var contentType: ContentType {
        get { return ContentType(rawValue: rawContentType) ?? .unknown }
        set { rawContentType = newValue.rawValue }
    }
}
