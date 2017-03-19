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
    
    var viewContext: NSManagedObjectContext = CoreDataController.shared.viewContext
    var jsonContext: NSManagedObjectContext = CoreDataController.shared.jsonContext
    
    func mapPosts(json: Any) throws -> [Post] {
        guard let children = ((json as? JSON)?["data"] as? JSON)?["children"] as? [JSON]
            else { throw APIClient.Errors.invalidResponse }
        
        let posts: [(id: String, name: String, json: JSON)] = children.flatMap(Post.id)
        let subredditNames = Set(posts.flatMap { $2["subreddit"] as? String })
        
        let existingPosts = try jsonContext.fetch({ () -> NSFetchRequest<Post> in
            let request = NSFetchRequest<Post>(entityName: String(describing: Post.self))
            request.predicate = NSPredicate(format: "id IN %@", posts.map { $0.id })
            return request
            }())
        let existingSubreddits = try jsonContext.fetch({ () -> NSFetchRequest<Subreddit> in
            let request = NSFetchRequest<Subreddit>(entityName: String(describing: Subreddit.self))
            request.predicate = NSPredicate(format: "name IN %@", Array(subredditNames))
            return request
            }())
        let subreddits = subredditNames.flatMap { name -> Subreddit in
            if let subreddit = existingSubreddits.first(where: { $0.name == name }) {
                return subreddit
            }
            let subreddit: Subreddit = create()
            subreddit.name = name
            return subreddit
        }
        return posts.flatMap { id, name, json -> Post? in
            if let post = existingPosts.first(where: { $0.id == id }) {
                return post
            }
            let post: Post = create()
            post.id = id
            post.name = name
            post.update(json: json)
            post.subreddit = subreddits.first { $0.name == post.subredditName }
            return post
        }
    }
    
    func mapComments(json: Any) throws -> [Comment] {
        guard let json = json as? [JSON],
            let posts = (json.first?["data"] as? JSON)?["children"] as? [JSON],
            let (postId, postName, postJSON) = posts.first.flatMap(Post.id)
            else { throw APIClient.Errors.invalidResponse }
        
        let post = try jsonContext.fetch({ () -> NSFetchRequest<Post> in
            let request = NSFetchRequest<Post>(entityName: String(describing: Post.self))
            request.predicate = NSPredicate(format: "id == %@", postId)
            return request
            }()).first ?? {
                let post: Post = create()
                post.id = postId
                post.name = postName
                return post
        }()
        post.update(json: postJSON)
        
        guard json.count > 1,
            let commentsJSON = (json[1]["data"] as? JSON)?["children"] as? [JSON]
            else { return [] }
        
        let existingComments: [Comment]
        if let id = postJSON["name"] as? String {
            let request = NSFetchRequest<Comment>(entityName: String(describing: Comment.self))
            request.predicate = NSPredicate(format: "postId == %@", id)
            existingComments = try jsonContext.fetch(request)
        } else {
            existingComments = []
        }
        
        let comments = commentsJSON.flatMap {
            mapComment(json: $0, parent: nil, existing: existingComments)
        }
        for (index, comment) in comments.enumerated() {
            comment.post = post
            comment.order = Int64(index)
        }
        return comments
    }
    
    @discardableResult
    private func mapComment(json: JSON, parent: Comment?, existing: [Comment]) -> [Comment] {
        guard let (id, name, json) = Comment.id(from: json) else { return [] }
        let comment = existing.first(where: { $0.id == id }) ?? {
            let comment: Comment = create()
            comment.id = id
            comment.name = name
            return comment
        }()
        comment.update(json: json)
        comment.parent = parent
        
        let replyJSON = ((json["replies"] as? JSON)?["data"] as? JSON)?["children"] as? [JSON] ?? []
        return [comment] + replyJSON.flatMap {
            mapComment(json: $0, parent: comment, existing: existing)
        }
    }

    func create<T: NSManagedObject>() -> T {
        let entityName = String(describing: T.self)
        let anyModel = NSEntityDescription.insertNewObject(forEntityName: entityName, into: jsonContext)
        return anyModel as? T ?? {
            fatalError("Managed object \(entityName) did not create as type \(T.self), instead it was created as \(type(of: anyModel))")
        }()
    }
}
