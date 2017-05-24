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
    
    var context: NSManagedObjectContext
    let moreCommentsBatchSize = 3
    let mapper = Mapper()
    
    private static var hasImported = false
    
    init() {
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = TestableCoreDataController.parent
        if !TestableCoreDataController.hasImported {
            importPosts(to: TestableCoreDataController.parent)
            TestableCoreDataController.hasImported = true
        }
    }
    
    func reset() {
        context.reset()
        TestableCoreDataController.parent.reset()
        context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.parent = TestableCoreDataController.parent
    }
    
    func newEmptyManagedObjectContext() -> NSManagedObjectContext {
        let store = NSPersistentStoreCoordinator(managedObjectModel: CoreDataController.managedObjectModel)
        do {
            try store.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        } catch {
            fatalError("Error adding store: \(error)")
        }
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = store
        return context
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
    
    struct ImportOptions: OptionSet {
        let rawValue: Int
        static let comments = ImportOptions(rawValue: 1 << 0)
        static let moreComments = ImportOptions(rawValue: 1 << 1)
    }
    
    func importPosts(to context: NSManagedObjectContext, including `import`: ImportOptions = [.comments, .moreComments]) {
        mapper.context = context
        
        print("TestableCoreDataController: Starting import of test models")
        let start = Date()
        
        let postsFilename = OfflineRemoteProvider.postsFilename()
        guard let postsJSON = TestableCoreDataController.fileJSON[postsFilename] else {
            fatalError("No file \(postsFilename) loaded in main bundle. Cannot run tests")
        }
        
        do {
            let posts = try mapper.mapPosts(json: postsJSON)
            
            /* Speed up fetching existing objects without using the slower NSFetchRequest */
            mapper.fetchExistingPosts = { _, _ in posts }
            mapper.fetchExistingComments = { postId, _ in Array(posts.first { $0.id == postId }?.comments ?? [])}
            mapper.fetchPost = { postId, _ in posts.first { $0.id == postId }}
            
            if `import`.contains(.comments) {
                try posts.forEach { try importComments(from: $0, including: `import`) }
            }
        } catch {
            fatalError("Error loading the testing managed object context: \(error)")
        }
        print("TestableCoreDataController: Finished -- took \(-start.timeIntervalSinceNow) seconds")
    }
    
    private func importComments(from post: Post, including `import`: ImportOptions) throws {
        let commentsFilename = OfflineRemoteProvider.commentsFilename(post: post)
        guard let commentsJSON = TestableCoreDataController.fileJSON[commentsFilename] else { return }
        _ = try mapper.mapComments(json: commentsJSON)
        
        guard `import`.contains(.moreComments) else { return }
        
        let moresBatched = batch(comments: post.displayComments(sortedBy: .best), maximum: moreCommentsBatchSize)
        for moreComments in moresBatched {
            if let moresFilename = OfflineRemoteProvider.moreCommentsFilename(post: post, mores: moreComments),
                let moresJSON = TestableCoreDataController.fileJSON[moresFilename] {
                _ = try mapper.mapMoreComments(json: moresJSON, mores: moreComments, post: post)
            }
        }
    }
}
