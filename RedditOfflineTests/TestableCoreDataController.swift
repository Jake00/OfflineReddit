//
//  TestableCoreDataController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 13/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData
import BoltsSwift
@testable import OfflineReddit

class TestableCoreDataController {
    
    let context: NSManagedObjectContext
    let moreCommentsBatchSize = 3
    
    init() {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: CoreDataController.managedObjectModel)
        
        do {
            try persistentStoreCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        } catch {
            fatalError("Error migrating store: \(error)")
        }
        
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        
        importModels()
    }
    
    func importModels() {
        var completed = false
        let provider = OfflineRemoteProvider()
        provider.logs = false
        provider.delays = false
        provider.context = context
        provider.mapper.context = context
        provider.getPosts(for: [], after: nil)
            .continueOnSuccessWithTask { posts -> Task<[Post]> in
                return Task<[Comment]>.whenAll(posts.map(provider.getComments))
                    .continueOnSuccessWith { posts }
            }.continueOnSuccessWithTask { posts -> Task<Void> in
                let tasks = posts.flatMap { post -> Task<Void> in
                    let mores = batch(comments: post.displayComments, maximum: self.moreCommentsBatchSize)
                    return Task<[Comment]>.whenAll(mores.map {
                        provider.getMoreComments(using: $0, post: post)
                    })
                }
                return Task<Void>.whenAll(tasks)
            }.continueWith { _ in
                completed = true
        }
        
        while !completed {
            let interval: TimeInterval = 0.002
            if !RunLoop.current.run(mode: .defaultRunLoopMode, before: Date(timeIntervalSinceNow: interval)) {
                Thread.sleep(forTimeInterval: interval)
            }
        }
    }
}
