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
    
    func getAllOfflinePosts(for subreddits: [Subreddit], sortedBy sort: Post.Sort, period: Post.SortPeriod?) -> Task<[Post]> {
        let request = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND isRead == NO AND subredditName IN %@", subreddits.map { $0.name }))
        return local.fetch(request)
    }
    
    func getPosts(for subreddits: [Subreddit], after post: Post?, sortedBy sort: Post.Sort, period: Post.SortPeriod?) -> Task<[Post]> {
        return remote.getPosts(for: subreddits, after: post, sortedBy: sort, period: period)
    }
}
