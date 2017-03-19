//
//  Post.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class Post: NSManagedObject {
    
    @NSManaged var author: String?
    @NSManaged var id: String
    @NSManaged var selfText: String?
    @NSManaged var subredditName: String?
    @NSManaged var subredditNamePrefixed: String?
    @NSManaged var permalink: String?
    @NSManaged var urlValue: String?
    @NSManaged var title: String?
    @NSManaged var name: String
    @NSManaged var created: Date?
    @NSManaged var isAvailableOffline: Bool
    @NSManaged var score: Int64
    @NSManaged var order: Int64
    @NSManaged var commentsCount: Int64
    @NSManaged var subreddit: Subreddit?
    @NSManaged var comments: Set<Comment>
}

extension Post {
    
    static func id(from json: JSON) -> (String, String, JSON)? {
        let data = json["data"] as? JSON ?? json
        if let subredditId = data["subreddit_id"] as? String,
            let postId = data["name"] as? String {
            return (subredditId + "/" + postId, postId, data)
        }
        return nil
    }
    
    var url: URL? {
        return urlValue.flatMap(URL.init(string:))
    }
    
    var scoreCommentsText: String {
        return "\(score) score • \(commentsCount) comments"
    }
    
    func update(json: JSON) {
        author = json["author"] as? String
        selfText = json["selftext"] as? String
        subredditName = json["subreddit"] as? String
        subredditNamePrefixed = json["subreddit_name_prefixed"] as? String
        permalink = json["permalink"] as? String
        urlValue = json["url"] as? String
        title = json["title"] as? String
        created = (json["created_utc"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        commentsCount = (json["num_comments"] as? Int).map(Int64.init) ?? 0
        score = (json["score"] as? Int).map(Int64.init) ?? 0
    }
}

extension Post: Identifiable { }

extension Post: AuthorTime { }

extension Post: Comparable { }

func < (lhs: Post, rhs: Post) -> Bool {
    return lhs.order < rhs.order
}
