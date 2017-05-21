//
//  PostsProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData
import BoltsSwift

final class PostsProvider {
    
    let remote: RemoteDataProviding
    let local: NSManagedObjectContext
    
    init(provider: DataProvider) {
        self.remote = provider.remote
        self.local = provider.local
    }
    
    func getAllOfflinePosts(for subreddits: [Subreddit]) -> Task<[Post]> {
        let source = TaskCompletionSource<[Post]>()
        let request = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND subredditName IN %@", subreddits.map { $0.name }))
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        local.performGrouped {
            let posts = (try? self.local.fetch(request)) ?? []
            source.set(result: posts)
        }
        return source.task
    }
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<[Post]> {
        return remote.getPosts(for: subreddits, after: post)
    }
    
    func getAllSelectedSubreddits() -> Task<[Subreddit]> {
        let source = TaskCompletionSource<[Subreddit]>()
        let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
        local.performGrouped {
            let subreddits = (try? self.local.fetch(request)) ?? []
            source.trySet(result: subreddits)
        }
        return source.task
    }
}
