//
//  CoreDataController.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 25/11/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import CoreData

final class CoreDataController {
    
    static let shared = CoreDataController()
    
    static let backingStoreURL: URL = {
        guard var url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("No documents directory available on this device")
        }
        url.appendPathComponent("ThisOrThat.sqlite")
        return url
    }()
    
    let viewContext: NSManagedObjectContext
    let jsonContext: NSManagedObjectContext
    
    init() {
        guard let modelURL = Bundle.main.url(forResource: "OfflineReddit", withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Error initializing managed object model from: \(modelURL)")
        }
        
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: mom)
        
        do {
            try persistentStoreCoordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: CoreDataController.backingStoreURL, options: nil)
        } catch {
            fatalError("Error migrating store: \(error)")
        }
        
        viewContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        viewContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        jsonContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        jsonContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        jsonContext.persistentStoreCoordinator = persistentStoreCoordinator
        
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: jsonContext)
    }
    
    private dynamic func contextDidSave(_ notification: Notification) {
        viewContext.mergeChanges(fromContextDidSave: notification)
//        let context = viewContext
//        context.performAndWait {
//            context.mergeChanges(fromContextDidSave: notification)
//            if context.hasChanges {
//                do {
//                    try context.save()
//                } catch {
//                    print("Error saving context: \(context): \(error)")
//                }
//            }
//        }
    }
    
    static func deleteCoreDataStore() {
        _ = try? FileManager.default.removeItem(at: backingStoreURL)
    }
}
