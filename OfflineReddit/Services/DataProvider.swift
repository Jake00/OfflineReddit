//
//  DataProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import BoltsSwift

protocol DataProvider {
    
    func getPosts(for subreddits: [Subreddit], after: Post?) -> Task<[Post]>
    func getComments(for post: Post) -> Task<[Comment]>
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]>
}

var dataProvider: DataProvider = APIClient.shared
