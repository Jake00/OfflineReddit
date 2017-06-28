//
//  NSManagedObject+Create.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData
import BoltsSwift

extension NSManagedObject {
    
    static func create<T: NSManagedObject>(in context: NSManagedObjectContext) -> T {
        let entityName = String(describing: T.self)
        let anyModel = NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
        return anyModel as? T ?? {
            fatalError(
                "Managed object \(entityName) did not create as type \(T.self), "
                + "instead it was created as \(type(of: anyModel))")
            }()
    }
    
    @nonobjc static func fetchRequest<T: NSManagedObject>(predicate: NSPredicate? = nil) -> NSFetchRequest<T> {
        let fetchRequest: NSFetchRequest<T> = NSFetchRequest(entityName: String(describing: T.self))
        fetchRequest.predicate = predicate
        return fetchRequest
    }
    
    func inContext(_ context: NSManagedObjectContext, inContextsQueue: Bool = true) -> Self {
        func selfInContext<T>() -> T {
            let map = { (context: NSManagedObjectContext) in
                // swiftlint:disable:next force_cast
                context.object(with: self.objectID) as! T
            }
            return inContextsQueue ? context.performAndWait(map) : map(context)
        }
        return managedObjectContext == context ? self : selfInContext()
    }
}

extension Collection where Iterator.Element: NSManagedObject {
    
    func inContext(
        _ context: NSManagedObjectContext,
        inContextsQueue: Bool = true
        ) -> [Iterator.Element] {
        
        let map = { (context: NSManagedObjectContext) in
            self.map {
                $0.managedObjectContext == context
                    ? $0
                    : context.object(with: $0.objectID)
                } as! [Iterator.Element]
            // swiftlint:disable:previous force_cast
        }
        return inContextsQueue ? context.performAndWait(map) : map(context)
    }
}

private var dispatchGroupKey = 222

extension NSManagedObjectContext {
    
    var dispatchGroup: DispatchGroup? {
        get { return objc_getAssociatedObject(self, &dispatchGroupKey) as? DispatchGroup }
        set { objc_setAssociatedObject(self, &dispatchGroupKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    open func performGrouped(_ block: @escaping () -> Void) {
        guard let group = dispatchGroup else { perform(block); return }
        group.enter()
        perform {
            block()
            group.leave()
        }
    }
    
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
    
    func trySave() {
        performGrouped {
            _ = try? self.save()
        }
    }
    
    func fetch<T>(_ request: NSFetchRequest<T>) -> Task<[T]> where T : NSFetchRequestResult {
        let source = TaskCompletionSource<[T]>()
        performGrouped {
            do {
                let result = try self.fetch(request) as [T]
                source.set(result: result)
            } catch {
                source.set(error: error)
            }
        }
        return source.task
    }
}
