//
//  NSManagedObject+Create.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData

extension NSManagedObject {
    
    static func create<T: NSManagedObject>(in context: NSManagedObjectContext) -> T {
        let entityName = String(describing: T.self)
        let anyModel = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        return anyModel as? T ?? {
            fatalError("Managed object \(entityName) did not create as type \(T.self), instead it was created as \(type(of: anyModel))")
            }()
    }
    
    static func fetchRequest<T: NSManagedObject>(predicate: NSPredicate) -> NSFetchRequest<T> {
        let fetchRequest: NSFetchRequest<T> = NSFetchRequest(entityName: String(describing: T.self))
        fetchRequest.predicate = predicate
        return fetchRequest
    }
}

extension Collection where Iterator.Element: NSManagedObject {
    
    func inContext(_ context: NSManagedObjectContext) -> [Iterator.Element] {
        return context.performAndWait { context in
            self.map { context.object(with: $0.objectID) } as! [Iterator.Element]
        }
    }
}

extension NSManagedObjectContext {
    
    func performAndWait<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) throws -> T {
        var value: Either<T, Error>?
        performAndWait { () -> Void in
            do {
                value = try .first(block(self))
            } catch {
                value = .other(error)
            }
        }
        switch value {
        case .first(let v)?: return v
        case .other(let e)?: throw e
        default: fatalError("Result was not set. This should never happen.")
        }
    }
    
    func performAndWait<T>(_ block: @escaping (NSManagedObjectContext) -> T) -> T {
        var value: T?
        performAndWait { () -> Void in
            value = block(self)
        }
        return value!
    }
}