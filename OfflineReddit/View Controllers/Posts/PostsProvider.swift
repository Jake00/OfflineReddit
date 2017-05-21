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
        let request = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND isRead == NO AND subredditName IN %@", subreddits.map { $0.name }))
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return local.fetch(request)
    }
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<[Post]> {
        return remote.getPosts(for: subreddits, after: post)
    }
}
