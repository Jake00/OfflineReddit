//
//  AsyncOperation.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 5/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation

class AsyncOperation: Operation {
    
    override var isAsynchronous: Bool { return true }
    
    private let lock = NSLock()
    
    private var _executing: Bool = false
    override private(set) var isExecuting: Bool {
        get { return lock.withLocked { _executing }}
        set {
            willChangeValue(forKey: "isExecuting")
            lock.withLocked { _executing = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _finished: Bool = false
    override private(set) var isFinished: Bool {
        get { return lock.withLocked { _finished }}
        set {
            willChangeValue(forKey: "isFinished")
            lock.withLocked { _finished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    func complete() {
        if isExecuting {
            isExecuting = false
        }
        if !isFinished {
            isFinished = true
        }
    }
    
    override func start() {
        if isCancelled {
            isFinished = true
            return
        }
        isExecuting = true
        main()
    }
    
    override func main() {
        fatalError("subclasses must override `main`")
    }
}

private extension NSLock {
    
    func withLocked<T>(_ execute: (Void) -> T) -> T {
        lock()
        let value = execute()
        unlock()
        return value
    }
}

class NetworkOperation: AsyncOperation {
    
    var task: URLSessionTask?
    
    override func main() {
        guard let task = task else {
            complete(); return
        }
        APIClient.logRequest(task)
        task.resume()
    }
    
    override func cancel() {
        task?.cancel()
        super.cancel()
    }
}
