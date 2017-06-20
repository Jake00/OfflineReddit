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
    @NSManaged var created: Date
    @NSManaged var isRead: Bool
    @NSManaged var isAvailableOffline: Bool
    @NSManaged var score: Int64
    @NSManaged var orderHot: Double
    @NSManaged var orderControversial: Double
    @NSManaged var upvoteRatio: Double
    @NSManaged var commentsCount: Int64
    @NSManaged var previewJSON: JSON?
    @NSManaged var subreddit: Subreddit?
    @NSManaged var comments: Set<Comment>
    @NSManaged var more: MoreComments?
    
    @NSManaged private var primitiveIsAvailableOffline: NSNumber
    @NSManaged private var primitiveIsRead: NSNumber
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        primitiveIsAvailableOffline = false as NSNumber
        primitiveIsRead = false as NSNumber
    }
    
    lazy var preview: PostImagePreviews? = { PostImagePreviews(json: self.previewJSON) }()
}

extension Post {
    
    static func fetchRequest(predicate: NSPredicate) -> NSFetchRequest<Post> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<Post>
    }
    
    var url: URL? {
        return urlValue.flatMap(URL.init(string:))
    }
    
    var votesEstimate: (upvotes: Int64, downvotes: Int64) {
        let dividend = Double(score) * upvoteRatio
        let divisor = 2 * upvoteRatio - 1
        let upvotes = Int64((dividend / divisor).rounded())
        let downvotes = score - upvotes
        return (upvotes, downvotes)
    }
    
    var scoreCommentsText: String {
        return "\(score) points • \(commentsCount) comments"
    }
    
    var subredditAuthorTimeText: String {
        let subreddit = subredditNamePrefixed ?? subredditName ?? SharedText.unknown
        return subreddit + " • " + authorTimeText
    }
    
    var authorTimeText: String {
        let author = self.author.map { "u/" + $0 } ?? SharedText.unknown
        let time = intervalFormatter.string(from: -created.timeIntervalSinceNow)
            .map { String.localizedStringWithFormat(SharedText.agoFormat, $0) }
            ?? SharedText.unknown
        return author + " • " + time
    }
    
    var displayComments: [Either<Comment, MoreComments>] {
        var displayComments = comments.flatMap { $0.displayComments }
        if let more = more {
            displayComments.append(.other(more))
        }
        return displayComments
    }
    
    var allMoreComments: [MoreComments] {
        var allMoreComments = comments.flatMap { $0.allMoreComments }
        if let more = more {
            allMoreComments.append(more)
        }
        return allMoreComments
    }
    
    func update(json: JSON) {
        author = json["author"] as? String
        selfText = json["selftext"] as? String
        if selfText?.isEmpty == true { selfText = nil }
        subredditName = json["subreddit"] as? String
        subredditNamePrefixed = json["subreddit_name_prefixed"] as? String
        permalink = json["permalink"] as? String
        urlValue = json["url"] as? String
        title = json["title"] as? String
        created = (json["created_utc"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        commentsCount = (json["num_comments"] as? Int).map(Int64.init) ?? 0
        score = (json["score"] as? Int).map(Int64.init) ?? 0
        upvoteRatio = json["upvote_ratio"] as? Double ?? 0
        previewJSON = json["preview"] as? JSON
    }
}

extension Post: Identifiable { }

extension Post {
    
    override var debugDescription: String {
        let maximumCharacters = 40
        var selfText = self.selfText ?? ""
        if selfText.characters.count > maximumCharacters {
            let index = selfText.index(selfText.startIndex, offsetBy: maximumCharacters - 3)
            selfText = selfText.substring(to: index) + "..."
        }
        selfText = selfText.replacingOccurrences(of: "\n", with: "\\n", options: .literal)
        return "\nPost \(id) by \(author ?? "") with \(comments.count) replies: \(selfText)"
    }
}
