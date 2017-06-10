//
//  Comment.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

class Comment: NSManagedObject {
    
    @NSManaged var id: String
    @NSManaged var shortId: String?
    @NSManaged var author: String?
    @NSManaged var body: String?
    @NSManaged var created: Date
    @NSManaged var gildedCount: Int64
    @NSManaged var parentId: String?
    @NSManaged var postId: String?
    @NSManaged var score: Int64
    @NSManaged var isScoreHidden: Bool
    @NSManaged var isControversial: Bool
    @NSManaged var depth: Int64
    @NSManaged var children: Set<Comment>
    @NSManaged var more: MoreComments?
    
    // The parent is either a comment or a post so only one of these will be non-nil.
    @NSManaged var parent: Comment?
    @NSManaged var post: Post?
}

extension Comment {
    
    static func fetchRequest(predicate: NSPredicate) -> NSFetchRequest<Comment> {
        return NSManagedObject.fetchRequest(predicate: predicate) as NSFetchRequest<Comment>
    }
    
    func update(json: JSON) {
        author = json["author"] as? String
        body = json["body"] as? String
        parentId = json["parent_id"] as? String
        created = (json["created_utc"] as? TimeInterval).map(Date.init(timeIntervalSince1970:)) ?? Date()
        gildedCount = (json["gilded"] as? Int).map(Int64.init) ?? 0
        score = (json["score"] as? Int).map(Int64.init) ?? 0
        isScoreHidden = json["score_hidden"] as? Bool ?? false
        isControversial = json["controversiality"] as? Int == 1
        depth = (json["depth"] as? Int).map(Int64.init) ?? 0
        postId = json["link_id"] as? String
        shortId = json["id"] as? String
    }
    
    var owningPost: Post? {
        return post ?? parent?.owningPost
    }
    
    var displayComments: [Either<Comment, MoreComments>] {
        var displayComments: [Either<Comment, MoreComments>] = []
        buildDisplayComments(accumulator: &displayComments)
        return displayComments
    }
    
    private func buildDisplayComments(accumulator: inout [Either<Comment, MoreComments>]) {
        accumulator.append(.first(self))
        for child in children {
            child.buildDisplayComments(accumulator: &accumulator)
        }
        if let more = more {
            accumulator.append(.other(more))
        }
    }
    
    var allMoreComments: [MoreComments] {
        var allMoreComments: [MoreComments] = []
        buildAllMoreComments(accumulator: &allMoreComments)
        return allMoreComments
    }
    
    private func buildAllMoreComments(accumulator: inout [MoreComments]) {
        for child in children {
            child.buildAllMoreComments(accumulator: &accumulator)
        }
        if let more = more {
            accumulator.append(more)
        }
    }
    
    var authorScoreTimeText: String {
        let author = self.author.map { "u/" + $0 } ?? SharedText.unknown
        let time = intervalFormatter.string(from: -created.timeIntervalSinceNow)
            .map { String.localizedStringWithFormat(SharedText.agoFormat, $0) }
            ?? SharedText.unknown
        return "\(author) • \(score) points • \(time)"
    }
}

extension Comment: Identifiable { }

extension Comment {
    
    override var debugDescription: String {
        let maximumCharacters = 40
        var body = self.body ?? ""
        if body.characters.count > maximumCharacters {
            let index = body.index(body.startIndex, offsetBy: maximumCharacters - 3)
            body = body.substring(to: index) + "..."
        }
        body = body.replacingOccurrences(of: "\n", with: "\\n", options: .literal)
        return "\nComment \(id) depth \(depth) score \(score) by \(author ?? "") with \(children.count) replies: \(body)"
    }
}
