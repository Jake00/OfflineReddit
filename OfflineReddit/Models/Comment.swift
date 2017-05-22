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
    @NSManaged var created: Date?
    @NSManaged var gildedCount: Int64
    @NSManaged var parentId: String?
    @NSManaged var postId: String?
    @NSManaged var score: Int64
    @NSManaged var isScoreHidden: Bool
    @NSManaged var depth: Int64
    @NSManaged var order: Int64
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
        created = (json["created_utc"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        gildedCount = (json["gilded"] as? Int).map(Int64.init) ?? 0
        score = (json["score"] as? Int).map(Int64.init) ?? 0
        isScoreHidden = json["score_hidden"] as? Bool ?? false
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
        let time = created
            .flatMap { intervalFormatter.string(from: -$0.timeIntervalSinceNow) }
            .map { String.localizedStringWithFormat(SharedText.agoFormat, $0) }
            ?? SharedText.unknown
        return "\(author) • \(score) points • \(time)"
    }
}

extension Comment: Identifiable { }

extension Comment: Comparable {
    enum Sort {
        case best, top
        
        static let all: [Sort] = [.best, .top]
        
        var displayName: String {
            switch self {
            case .best: return SharedText.best
            case .top: return SharedText.top
            }
        }
    }
}

func < (lhs: Comment, rhs: Comment) -> Bool {
    return best(lhs: lhs, rhs: rhs)
}

private func compare(_ lhs: Comment, _ rhs: Comment, _ comparison: (Comment, Comment) -> Bool) -> Bool {
    if lhs.parent == rhs.parent {
        return comparison(lhs, rhs)
    }
    let lhsHierarchy = lhs.hierarchy
    let rhsHierarchy = rhs.hierarchy
    
    for (index, lhsComment) in lhsHierarchy.enumerated() where index < rhsHierarchy.endIndex {
        let rhsComment = rhsHierarchy[index]
        if lhsComment != rhsComment {
            return comparison(lhsComment, rhsComment)
        }
    }
    return rhsHierarchy.contains(lhs) || !lhsHierarchy.contains(rhs)
}

/// This named is to enable the syntax `comments.sorted(by: best)`
private func best(lhs: Comment, rhs: Comment) -> Bool {
    return compare(lhs, rhs) { $0.order < $1.order }
}

/// This named is to enable the syntax `comments.sorted(by: top)`
private func top(lhs: Comment, rhs: Comment) -> Bool {
    return compare(lhs, rhs) { $0.score > $1.score }
}

extension Collection where Iterator.Element == Comment {
    
    var allNested: Set<Comment> {
        var comments: Set<Comment> = []
        for comment in self {
            comments.formUnion(comment.all)
        }
        return comments
    }
    
    func sorted(by sorting: Comment.Sort) -> [Comment] {
        switch sorting {
        case .best: return sorted(by: best)
        case .top: return sorted(by: top)
        }
    }
}
