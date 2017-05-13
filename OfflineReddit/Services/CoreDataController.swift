//
//  CoreDataController.swift
//  OfflineReddit
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
        url.appendPathComponent("OfflineReddit.sqlite")
        return url
    }()
    
    static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle.main.url(forResource: "OfflineReddit", withExtension:"momd") else {
            fatalError("Error loading model from bundle")
        }
        guard let mom = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Error initializing managed object model from: \(url)")
        }
        return mom
    }()
    
    let viewContext: NSManagedObjectContext
    let jsonContext: NSManagedObjectContext
    
    init() {
        let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: CoreDataController.managedObjectModel)
        
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
        NotificationCenter.default.addObserver(self, selector: #selector(contextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: viewContext)
    }
    
    private var saving: NSManagedObjectContext?
    
    private dynamic func contextDidSave(_ notification: Notification) {
        guard let object = notification.object as? NSManagedObjectContext, object == viewContext || object == jsonContext, saving == nil
            else { return }
        let context = object == jsonContext ? viewContext : jsonContext
        context.performAndWait {
            self.saving = context
            context.mergeChanges(fromContextDidSave: notification)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Error saving context: \(context): \(error)")
                }
            }
            self.saving = nil
        }
    }
    
    static func deleteCoreDataStore() {
        _ = try? FileManager.default.removeItem(at: backingStoreURL)
    }
}
