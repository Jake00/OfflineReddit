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
    
    private(set) var context: NSManagedObjectContext
    let moreCommentsBatchSize = 3
    let mapper = Mapper()
    
    private static var hasImported = false
    
    init() {
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = TestableCoreDataController.parent
        if !TestableCoreDataController.hasImported {
            mapper.context = TestableCoreDataController.parent
            importModels()
            TestableCoreDataController.hasImported = true
        }
    }
    
    func reset() {
        context.reset()
        TestableCoreDataController.parent.reset()
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = TestableCoreDataController.parent
    }
    
    private static let parent: NSManagedObjectContext = {
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = persistentStoreCoordinator
        return context
    }()
    
    static let persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let store = NSPersistentStoreCoordinator(managedObjectModel: CoreDataController.managedObjectModel)
        do {
            try store.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        } catch {
            fatalError("Error adding store: \(error)")
        }
        return store
    }()
    
    static let fileJSON: [String: Any] = {
        var fileJSON: [String: Any] = [:]
        let stored = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: OfflineRemoteProvider.subdirectory) ?? []
        for url in stored {
            if let data = try? Data(contentsOf: url),
                let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                var filename = url
                filename.deletePathExtension()
                fileJSON[filename.lastPathComponent] = json
            }
        }
        return fileJSON
    }()
    
    func importModels() {
        print("starting import of test models")
        let start = Date()
        
        let postsFilename = OfflineRemoteProvider.postsFilename()
        guard let postsJSON = TestableCoreDataController.fileJSON[postsFilename] else {
            fatalError("No file \(postsFilename) loaded in main bundle. Cannot run tests")
        }
        let posts: [Post]
        do {
            posts = try mapper.mapPosts(json: postsJSON)
        } catch {
            fatalError("Error loading the testing managed object context: \(error)")
        }
        
        mapper.fetchExistingPosts = { _, _ in posts }
        mapper.fetchExistingComments = { postId, _ in Array(posts.first { $0.id == postId }?.comments ?? [])}
        mapper.fetchPost = { postId, _ in posts.first { $0.id == postId }}
        
        let iterations = 4
        let numberOfElements = posts.count / iterations
        var completed = false
        
        DispatchQueue.global().async {
            DispatchQueue.concurrentPerform(iterations: iterations) {
                let startIndex = $0 * numberOfElements
                let endIndex = $0 == iterations - 1 ? posts.endIndex : startIndex + numberOfElements
                do {
                    try posts[startIndex..<endIndex].forEach(self.importModels(from:))
                } catch {
                    fatalError("Error loading the testing managed object context: \(error)")
                }
            }
            completed = true
        }
        
        /* Block the main thread until import is complete, but allow the context to queue work. */
        while !completed {
            let interval = 0.002
            let date = Date(timeIntervalSinceNow: interval)
            if !RunLoop.main.run(mode: .defaultRunLoopMode, before: date) {
                Thread.sleep(forTimeInterval: interval)
            }
        }
        print("finished -- took \(-start.timeIntervalSinceNow) seconds")
    }
    
    private func importModels(from post: Post) throws {
        let commentsFilename = OfflineRemoteProvider.commentsFilename(post: post)
        guard let commentsJSON = TestableCoreDataController.fileJSON[commentsFilename] else { return }
        _ = try self.mapper.mapComments(json: commentsJSON)
        
        let moresBatched = batch(comments: post.displayComments, maximum: self.moreCommentsBatchSize)
        for moreComments in moresBatched {
            if let moresFilename = OfflineRemoteProvider.moreCommentsFilename(post: post, mores: moreComments),
                let moresJSON = TestableCoreDataController.fileJSON[moresFilename] {
                _ = try self.mapper.mapMoreComments(json: moresJSON, mores: moreComments, post: post)
            }
        }
    }
}
