//
//  CommentsProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData
import BoltsSwift

final class CommentsProvider {
    
    let remote: RemoteDataProviding
    let local: NSManagedObjectContext
    
    init(provider: DataProvider) {
        self.remote = provider.remote
        self.local = provider.local
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
