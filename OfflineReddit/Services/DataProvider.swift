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
    func getPosts(for subreddits: [Subreddit], after post: Post?, sortedBy sort: Post.Sort, period: Post.SortPeriod?) -> Task<[Post]>
    func getComments(for post: Post, sortedBy sort: Comment.Sort) -> Task<[Comment]>
    func getMoreComments(using mores: [MoreComments], post: Post, sortedBy sort: Comment.Sort) -> Task<[Comment]>
}

struct DataProvider {
    let remote: RemoteDataProviding
    let local: NSManagedObjectContext
    let reachability: Reachability
}
/*
final class DataProvider {
    
    static let shared = DataProvider(remote: APIClient.shared, local: CoreDataController.shared.viewContext)
    
    var remote: DataProviding
    var local: NSManagedObjectContext
    lazy var reachability: Reachable = Reachability.shared
    
    init(remote: DataProviding, local: NSManagedObjectContext) {
        self.remote = remote
        self.local = local
    }
    
    func save() {
        local.performGrouped {
            _ = try? self.local.save()
        }
    }
    
    enum UpdateContext {
        case append, replace
    }
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<([Post], UpdateContext)> {
        if reachability.isOnline {
            return remote.getPosts(for: subreddits, after: post)
                .continueOnSuccessWith(.immediate) { ($0, .append) }
        }
        
        let source = TaskCompletionSource<([Post], UpdateContext)>()
        let request = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND subredditName IN %@", subreddits.map { $0.name }))
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        local.performGrouped {
            let posts = (try? self.local.fetch(request)) ?? []
            source.set(result: (posts, .replace))
        }
        return source.task
    }
    
    func getSelectedSubreddits() -> Task<[Subreddit]> {
        let source = TaskCompletionSource<[Subreddit]>()
        let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
        local.performGrouped {
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
*/
