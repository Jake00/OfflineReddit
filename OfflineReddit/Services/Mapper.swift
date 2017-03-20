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
    
    var context: NSManagedObjectContext = CoreDataController.shared.jsonContext
    
    func mapPosts(json: Any) throws -> [Post] {
        guard let children = ((json as? JSON)?["data"] as? JSON)?["children"] as? [JSON]
            else { throw APIClient.Errors.invalidResponse }
        
        let postsJSON: [(id: String, json: JSON)] = children.flatMap(Post.id)
        let subredditNames = Set(postsJSON.flatMap { $1["subreddit"] as? String })
        let postsRequest = Post.fetchRequest(predicate: NSPredicate(format: "id IN %@", postsJSON.map { $0.id }))
        let subredditsRequest = Subreddit.fetchRequest(predicate: NSPredicate(format: "name IN %@", Array(subredditNames)))
        
        return try context.performAndWait { context -> [Post] in
            let existingPosts = try context.fetch(postsRequest)
            let existingSubreddits = try context.fetch(subredditsRequest)
            
            let subreddits = subredditNames.flatMap { name -> Subreddit in
                existingSubreddits.first(where: { $0.name == name })
                    ?? Subreddit.create(in: context, name: name)
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
        
        let postsRequest = Post.fetchRequest(predicate: NSPredicate(format: "id == %@", postId))
        
        return try context.performAndWait { context -> [Comment] in
            let post = try context.fetch(postsRequest).first ?? Post.create(in: context, id: postId)
            post.update(json: postJSON)
            
            guard json.count > 1,
                let commentsJSON = (json[1]["data"] as? JSON)?["children"] as? [JSON]
                else { return [] }
            
            let existingComments: [Comment] = try (postJSON["name"] as? String).map {
                try context.fetch(Comment.fetchRequest(predicate: NSPredicate(format: "postId == %@", $0)))
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
        (parentComment?.more ?? parentPost?.more).map(context.delete)
        let moreComments = MoreComments.create(in: context, id: id)
        moreComments.update(json: json)
        parentComment?.more = moreComments
        parentPost?.more = moreComments
        return moreComments
    }
    
    func mapMoreComments(json: Any, more: MoreComments) throws -> [Comment] {
        return try context.performAndWait { context -> [Comment] in
            let more = more.managedObjectContext == context ? more : context.object(with: more.objectID) as! MoreComments
            guard let post = more.owningPost else { throw APIClient.Errors.missingFields }
            guard let json = ((json as? JSON)?["json"] as? JSON)?["data"] as? JSON,
                let commentsJSON = json["things"] as? [JSON]
                else { throw APIClient.Errors.invalidResponse }
            
            let commentsRequest = Comment.fetchRequest(predicate: NSPredicate(format: "postId == %@", post.id))
            
            let existingComments = try context.fetch(commentsRequest)
            var order = Int64(
                more.parentComment?.children.count
                ?? more.parentPost?.comments.count
                ?? 0)
            let comments = commentsJSON.flatMap { json -> [Comment] in
                guard let (parent, replies) = self.mapComment(json: json, parent: more.parentComment, topLevelPost: more.parentPost, existing: existingComments) else { return [] }
                parent.order = order
                order += 1
                return [parent] + replies
            }
            context.delete(more)
            try context.save()
            return comments
        }
    }
}
