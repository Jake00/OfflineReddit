//
//  Comment.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class Comment: NSManagedObject {
    
    @NSManaged var author: String?
    @NSManaged var body: String?
    @NSManaged var created: Date?
    @NSManaged var gildedCount: Int64
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var parentName: String?
    @NSManaged var postId: String?
    @NSManaged var score: Int64
    @NSManaged var isScoreHidden: Bool
    @NSManaged var depth: Int64
    @NSManaged var order: Int64
    @NSManaged var parent: Comment?
    @NSManaged var children: Set<Comment>
    @NSManaged var post: Post?
    
    var isExpanded = true
}

extension Comment {
    
    static func id(from json: JSON) -> (String, String, JSON)? {
        let data = json["data"] as? JSON ?? json
        if let subredditId = data["subreddit_id"] as? String,
            let postId = data["link_id"] as? String,
            let commentId = data["name"] as? String {
            return (subredditId + "/" + postId + "/" + commentId, commentId, data)
        }
        return nil
    }
    
    func update(json: JSON) {
        author = json["author"] as? String
        body = json["body"] as? String
        parentName = json["parent_name"] as? String
        created = (json["created_utc"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        gildedCount = (json["gilded"] as? Int).map(Int64.init) ?? 0
        score = (json["score"] as? Int).map(Int64.init) ?? 0
        isScoreHidden = json["score_hidden"] as? Bool ?? false
        depth = (json["depth"] as? Int).map(Int64.init) ?? 0
        postId = json["link_id"] as? String
    }
}

extension Comment: Identifiable { }

extension Comment: AuthorTime { }

extension Comment: Comparable { }

func < (lhs: Comment, rhs: Comment) -> Bool {
    return lhs.order < rhs.order
}
