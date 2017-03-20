//
//  Post.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class Post: NSManagedObject {
    
    @NSManaged var id: String
    @NSManaged var author: String?
    @NSManaged var selfText: String?
    @NSManaged var subredditName: String?
    @NSManaged var subredditNamePrefixed: String?
    @NSManaged var permalink: String?
    @NSManaged var urlValue: String?
    @NSManaged var title: String?
    @NSManaged var created: Date?
    @NSManaged var isAvailableOffline: Bool
    @NSManaged var score: Int64
    @NSManaged var order: Int64
    @NSManaged var commentsCount: Int64
    @NSManaged var subreddit: Subreddit?
    @NSManaged var comments: Set<Comment>
    @NSManaged var more: MoreComments?
}

extension Post {
    
    static func fetchRequest(predicate: NSPredicate) -> NSFetchRequest<Post> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<Post>
    }
    
    var url: URL? {
        return urlValue.flatMap(URL.init(string:))
    }
    
    var scoreCommentsText: String {
        return "\(score) score • \(commentsCount) comments"
    }
    
    var authorTimeText: String {
        let author = self.author.map { "u/" + $0 } ?? SharedText.unknown
        let time = created
            .flatMap { intervalFormatter.string(from: -$0.timeIntervalSinceNow) }
            .map { String.localizedStringWithFormat(SharedText.agoFormat, $0) }
            ?? SharedText.unknown
        return "\(author) • \(time)"
    }
    
    var displayComments: [Either<Comment, MoreComments>] {
        var displayComments = comments.sorted().flatMap { $0.displayComments }
        if let more = more {
            displayComments.append(.other(more))
        }
        return displayComments
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

extension Post: Comparable { }

func < (lhs: Post, rhs: Post) -> Bool {
    return lhs.order < rhs.order
}