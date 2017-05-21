//
//  Mapper.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import CoreData

typealias JSON = [String: Any]

final class Mapper {
    
    lazy var context = CoreDataController.shared.jsonContext
    
    var fetchExistingPosts: ([String], NSManagedObjectContext) throws -> [Post] = { ids, context in
        return try context.fetch(Post.fetchRequest(predicate: NSPredicate(format: "id IN %@", ids)))
    }
    
    var fetchPost: (String, NSManagedObjectContext) throws -> Post? = { id, context in
        return try context.fetch(Post.fetchRequest(predicate: NSPredicate(format: "id == %@", id))).first
    }
    
    var fetchExistingComments: (String, NSManagedObjectContext) throws -> [Comment] = { postId, context in
        return try context.fetch(Comment.fetchRequest(predicate: NSPredicate(format: "postId == %@", postId)))
    }
    
    func mapPosts(json: Any) throws -> [Post] {
        guard let children = ((json as? JSON)?["data"] as? JSON)?["children"] as? [JSON]
            else { throw APIClient.Errors.invalidResponse }
        
        let postsJSON: [(id: String, json: JSON)] = children.flatMap(Post.id)
        let subredditNames = Set(postsJSON.flatMap { $1["subreddit"] as? String })
        let subredditsRequest: NSFetchRequest<Subreddit> = Subreddit.fetchRequest()
        
        return try context.performAndWait { context -> [Post] in
            let existingPosts = try self.fetchExistingPosts(postsJSON.map { $0.id }, context)
            let existingSubreddits: [Subreddit] = try context.fetch(subredditsRequest)
            
            let subreddits = subredditNames.flatMap { name -> Subreddit in
                let subreddit = existingSubreddits.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
                    ?? Subreddit.create(in: context, name: name)
                subreddit.name = name
                return subreddit
            }
            let posts = postsJSON.flatMap { id, json -> Post? in
                if let post = existingPosts.first(where: { $0.id == id }) {
                    return post
                }
                let post = Post.create(in: context, id: id)
                post.update(json: json)
                post.subreddit = subreddits.first { $0.name == post.subredditName }
                return post
            }
            try context.save()
            return posts
        }
    }
    
    func mapComments(json: Any) throws -> [Comment] {
        guard let json = json as? [JSON],
            let posts = (json.first?["data"] as? JSON)?["children"] as? [JSON],
            let (postId, postJSON) = posts.first.flatMap(Post.id)
            else { throw APIClient.Errors.invalidResponse }
        
        return try context.performAndWait { context -> [Comment] in
            let post = try self.fetchPost(postId, context) ?? Post.create(in: context, id: postId)
            post.update(json: postJSON)
            
            guard json.count > 1,
                let commentsJSON = (json[1]["data"] as? JSON)?["children"] as? [JSON]
                else { return [] }
            
            let existingComments: [Comment] = try (postJSON["name"] as? String).map {
                try self.fetchExistingComments($0, context)
                } ?? []
            
            var order: Int64 = 0
            let comments = commentsJSON.flatMap { json -> [Comment] in
                guard let (parent, replies) = self.mapComment(json: json, parent: nil, topLevelPost: post, existing: existingComments) else { return [] }
                parent.order = order
                order += 1
                return [parent] + replies
            }
            try context.save()
            return comments
        }
    }
    
    private func mapComment(json: JSON, parent: Comment?, topLevelPost: Post?, existing: [Comment]) -> (Comment, [Comment])? {
        let isMoreComments = (json["kind"] as? String) == "more"
        guard !isMoreComments else {
            mapMoreComments(json: json, parentComment: parent, parentPost: topLevelPost)
            return nil
        }
        guard let (id, json) = Comment.id(from: json) else { return nil }
        let comment = existing.first(where: { $0.id == id }) ?? Comment.create(in: context, id: id)
        comment.update(json: json)
        comment.parent = parent
        comment.post = topLevelPost
        comment.more.map(context.delete)
        
        var order: Int64 = 0
        let replyJSON = ((json["replies"] as? JSON)?["data"] as? JSON)?["children"] as? [JSON] ?? []
        return (comment, replyJSON.flatMap { json -> [Comment] in
            guard let (parent, replies) = mapComment(json: json, parent: comment, topLevelPost: nil, existing: existing) else { return [] }
            parent.order = order
            order += 1
            return [parent] + replies
        })
    }
    
    @discardableResult
    private func mapMoreComments(json: JSON, parentComment: Comment?, parentPost: Post?) -> MoreComments? {
        guard let (id, json) = MoreComments.id(from: json) else { return nil }
        guard (json["count"] as? Int).map({ $0 > 0 }) ?? false else { return nil }
        (parentComment?.more ?? parentPost?.more).map(context.delete)
        let moreComments = MoreComments.create(in: context, id: id)
        moreComments.update(json: json)
        parentComment?.more = moreComments
        parentPost?.more = moreComments
        return moreComments
    }
    
    func mapMoreComments(json: Any, mores: [MoreComments], post: Post) throws -> [Comment] {
        guard let json = ((json as? JSON)?["json"] as? JSON)?["data"] as? JSON,
            let commentsJSON = json["things"] as? [JSON]
            else { throw APIClient.Errors.invalidResponse }
        
        return try context.performAndWait { context -> [Comment] in
            let mores = mores.inContext(context, inContextsQueue: false)
            let post = post.inContext(context, inContextsQueue: false)
            let existingComments = try self.fetchExistingComments(post.id, context)
            var orders: [MoreComments: Int64] = [:]
            mores.forEach { orders[$0] = Int64($0.parentComment?.children.count ?? $0.parentPost?.comments.count ?? 0) }
            
            /* 
             The Reddit API often sends back child comments that we did not request via a 'MoreComments' id.
             eg. Request comment 1 and 2. Reddit gives us back comments 1, 2 and 3.
             We handle this by putting them in the `unset` array and setting their relationship.
             */
            var unset: [Comment] = []
            
            let comments = commentsJSON.flatMap { json -> [Comment] in
                let more: MoreComments? = Comment.id(from: json)
                    .flatMap { $1["id"] as? String }
                    .flatMap { id in mores.first { $0.children.contains(id) }}
                
                guard let (parent, replies) = self.mapComment(
                    json: json,
                    parent: more?.parentComment,
                    topLevelPost: more?.parentPost,
                    existing: existingComments
                    ) else { return [] }
                
                if let more = more, let order = orders[more] {
                    parent.order = order
                    orders[more] = order + 1
                } else {
                    unset.append(parent)
                }
                return [parent] + replies
            }
            for comment in unset {
                guard let parentId = comment.parentId else { continue }
                if parentId == post.id {
                    comment.post = post
                } else if let parent = comments.first(where: { $0.id == parentId }) {
                    comment.parent = parent
                }
            }
            _ = mores.map(context.delete)
            try context.save()
            return comments
        }
    }
}
