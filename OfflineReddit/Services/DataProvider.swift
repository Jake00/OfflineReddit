//
//  DataProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import BoltsSwift
import CoreData

protocol DataProviding {
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<[Post]>
    func getComments(for post: Post) -> Task<[Comment]>
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]>
}

final class DataProvider {
    
    var remote: DataProviding
    let local: NSManagedObjectContext
    
    init(remote: DataProviding = APIClient.shared,
         local: NSManagedObjectContext = CoreDataController.shared.viewContext) {
        self.remote = remote
        self.local = local
    }
    
    enum UpdateContext {
        case append, replace
    }
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<([Post], UpdateContext)> {
        if isOnline {
            return remote.getPosts(for: subreddits, after: post)
                .continueOnSuccessWith(.immediate) { ($0, .append) }
        }
        
        let source = TaskCompletionSource<([Post], UpdateContext)>()
        let request = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND subredditName IN %@", subreddits.map { $0.name }))
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        local.perform {
            let posts = (try? self.local.fetch(request)) ?? []
            source.set(result: (posts, .replace))
        }
        return source.task
    }
    
    func getSelectedSubreddits() -> Task<[Subreddit]> {
        let source = TaskCompletionSource<[Subreddit]>()
        let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
        local.perform {
            let subreddits = (try? self.local.fetch(request)) ?? []
            source.trySet(result: subreddits)
        }
        return source.task
    }
    
    func getComments(for post: Post) -> Task<[Comment]> {
        return remote.getComments(for: post).continueOnSuccessWith(.immediate) {
            post.isAvailableOffline = true
            return $0
        }
    }
    
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]> {
        return remote.getMoreComments(using: mores, post: post)
    }
}
