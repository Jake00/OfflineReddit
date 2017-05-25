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
    @NSManaged var parent: Comment?
    @NSManaged var children: Set<Comment>
    @NSManaged var post: Post?
    @NSManaged var more: MoreComments?
    
    var isExpanded = true
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
        for child in children.sorted() {
            child.buildDisplayComments(accumulator: &accumulator)
        }
        if let more = more {
            accumulator.append(.other(more))
        }
    }
    
    var all: Set<Comment> {
        var all: Set<Comment> = []
        buildAll(accumulator: &all)
        return all
    }
    
    private func buildAll(accumulator: inout Set<Comment>) {
        accumulator.insert(self)
        for child in children {
            child.buildAll(accumulator: &accumulator)
        }
    }
    
    var hierarchy: [Comment] {
        var hierarchy: [Comment] = []
        buildHierarchy(accumulator: &hierarchy)
        return hierarchy
    }
    
    private func buildHierarchy(accumulator: inout [Comment]) {
        accumulator.insert(self, at: 0)
        parent?.buildHierarchy(accumulator: &accumulator)
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

extension Collection where Iterator.Element == Comment {
    
    var allNested: Set<Comment> {
        var comments: Set<Comment> = []
        for comment in self {
            comments.formUnion(comment.all)
        }
        return comments
    }
}
