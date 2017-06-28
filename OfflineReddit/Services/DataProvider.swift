//
//  DataProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import BoltsSwift
import CoreData

protocol RemoteDataProviding {
    
    func getPosts(
        for subreddits: [Subreddit],
        after post: Post?,
        sortedBy sort: Post.Sort,
        period: Post.SortPeriod?
        ) -> Task<[Post]>
    
    func getComments(
        for post: Post,
        sortedBy
        sort: Comment.Sort
        ) -> Task<[Comment]>
    
    func getMoreComments(
        using mores: [MoreComments],
        post: Post,
        sortedBy sort: Comment.Sort
        ) -> Task<[Comment]>
}

struct DataProvider {
    let remote: RemoteDataProviding
    let local: NSManagedObjectContext
    let reachability: Reachability
}
