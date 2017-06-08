//
//  WeakKeyDictionary.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

final class WeakKeyDictionary<Key: AnyObject, Value>: Collection, ExpressibleByDictionaryLiteral where Key: Hashable {
    
    fileprivate var buffer: [Weak<Key>: Value]
    
    typealias Element = (key: Weak<Key>, value: Value)
    typealias Index = Dictionary<Weak<Key>, Value>.Index
    
    var didRemoveValue: ((Value) -> Void)?
    
    // MARK: - Init
    
    init() {
        buffer = Dictionary()
    }
    
    init(minimumCapacity: Int) {
        buffer = Dictionary(minimumCapacity: minimumCapacity)
    }
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        var buffer: [Weak<Key>: Value] = [:]
        for (key, value) in elements {
            buffer[Weak(key)] = value
        }
        self.buffer = buffer
    }
    
    // MARK: - Dictionary
    
    var startIndex: Index {
        return buffer.startIndex
    }
    
    var endIndex: Index {
        return buffer.endIndex
    }
    
    var count: Int {
        return buffer.count
    }
    
    var isEmpty: Bool {
        return buffer.isEmpty
    }
    
    func index(after i: Index) -> Index {
        return buffer.index(after: i)
    }
    
    func index(forKey key: Key) -> Index? {
        return buffer.index(forKey: Weak(key))
    }
    
    func makeIterator() -> DictionaryIterator<Weak<Key>, Value> {
        return buffer.makeIterator()
    }
    
    var keys: LazyMapCollection<[Weak<Key> : Value], Weak<Key>> {
        return buffer.keys
    }
    
    var values: LazyMapCollection<[Weak<Key> : Value], Value> {
        return buffer.values
    }
    
    subscript(position: Index) -> (key: Weak<Key>, value: Value) {
        return buffer[position]
    }
    
    subscript(key: Key) -> Value? {
        get { return buffer[Weak(key)] }
        set {
            if let newValue = newValue {
                _ = updateValue(newValue, forKey: key)
            } else {
                _ = removeValue(forKey: key)
            }
        }
    }
    
    // MARK: - Mutating
    
    func updateValue(_ value: Value, forKey key: Key) -> Value? {
        let weak = Weak(key)
        let value = buffer.updateValue(value, forKey: weak)
        if let value = value {
            didRemoveValue?(value)
        } else {
            startWatching(weak, key)
        }
        return value
    }
    
    func remove(at index: Index) -> Element {
        let element = buffer.remove(at: index)
        element.key.value.map(stopWatching)
        didRemoveValue?(element.value)
        return element
    }
    
    func removeValue(forKey key: Key) -> Value? {
        let value = buffer.removeValue(forKey: Weak(key))
        if let value = value {
            stopWatching(key)
            didRemoveValue?(value)
        }
        return value
    }
    
    func removeAll(keepingCapacity keepCapacity: Bool = false) {
        let old = buffer
        buffer.removeAll(keepingCapacity: keepCapacity)
        for (key, value) in old {
            key.value.map(stopWatching)
            didRemoveValue?(value)
        }
    }
    
    // MARK: - Watching
    
    private func startWatching(_ weak: Weak<Key>, _ key: Key) {
        let watcher = DeallocNotify { [weak self] in
            if let value = self?.buffer.removeValue(forKey: weak) {
                self?.didRemoveValue?(value)
            }
        }
        objc_setAssociatedObject(key, &deallocWatcherKey, watcher, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
    private func stopWatching(_ key: Key) {
        objc_setAssociatedObject(key, &deallocWatcherKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - Equatable

extension WeakKeyDictionary where Key: Hashable, Value: Equatable {
    
    static func == (lhs: WeakKeyDictionary<Key, Value>, rhs: WeakKeyDictionary<Key, Value>) -> Bool {
        return lhs.buffer == rhs.buffer
    }
    
    static func != (lhs: WeakKeyDictionary<Key, Value>, rhs: WeakKeyDictionary<Key, Value>) -> Bool {
        return lhs.buffer != rhs.buffer
    }
}

// MARK: - String convertible

extension WeakKeyDictionary: CustomStringConvertible, CustomDebugStringConvertible {
    
    var description: String {
        return buffer.description
    }
    
    var debugDescription: String {
        return buffer.debugDescription
    }
}

// MARK: - Weak key

class Weak<T: AnyObject>: Hashable where T: Hashable {
    private(set) weak var value: T?
    let hashValue: Int
    
    init(_ value: T) {
        self.value = value
        self.hashValue = value.hashValue
    }
    
    static func == <T: Hashable>(lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        return lhs.value == rhs.value
    }
}

// MARK: - Deallocation notifier

private class DeallocNotify {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
    deinit { callback() }
}

private var deallocWatcherKey = 1
