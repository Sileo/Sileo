//
//  SafeContainers.swift
//  Sileo
//
//  Created by Andromeda on 07/09/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation


// MARK: SafeArray
final public class SafeArray<Element> {
    private var array: [Element]
    private var queue: DispatchQueue
    private var key: DispatchSpecificKey<Int>
    private var context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ array: [Element] = [], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.array = array
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    var count: Int {
        if !isOnQueue {
            var result = 0
            queue.sync { result = self.array.count }
            return result
        }
        return array.count
    }
    
    var isEmpty: Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.isEmpty }
            return result
        }
        return array.isEmpty
    }
    
    var raw: [Element] {
        if !isOnQueue {
            var result = [Element]()
            queue.sync { result = self.array }
            return result
        }
        return array
    }
    
    func contains(where package: (Element) -> Bool) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(where: package) }
            return result
        }
        return array.contains(where: package)
    }
    
    func setTo(_ packages: [Element]) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array = packages
            }
        } else {
            self.array = packages
        }
    }
    
    func append(_ package: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.append(package)
            }
        } else {
            self.array.append(package)
        }
    }
    
    func removeAll() {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.removeAll()
            }
        } else {
            self.array.removeAll()
        }
    }
    
    func removeAll(package: @escaping (Element) -> Bool) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                while let index = self.array.firstIndex(where: package) {
                    self.array.remove(at: index)
                }
            }
        } else {
            while let index = self.array.firstIndex(where: package) {
                self.array.remove(at: index)
            }
        }
    }
    
    func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        if !isOnQueue {
            var result = [ElementOfResult]()
            queue.sync { result = self.array.map(transform) }
            return result
        } else {
            return array.map(transform)
        }
    }
}

extension SafeArray where Element: Equatable {
    func contains(_ element: Element) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(element) }
            return result
        }
        return self.array.contains(element)
    }
}

// MARK: SafeContiguousArray
final public class SafeContiguousArray<Element> {
    private var array: ContiguousArray<Element>
    private var queue: DispatchQueue
    private var key: DispatchSpecificKey<Int>
    private var context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ array: ContiguousArray<Element> = [], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.array = array
        self.queue = queue
        self.key = key
        self.context = context
    }
    
    var count: Int {
        if !isOnQueue {
            var result = 0
            queue.sync { result = self.array.count }
            return result
        }
        return array.count
    }
    
    var isEmpty: Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.isEmpty }
            return result
        }
        return array.isEmpty
    }
    
    var raw: ContiguousArray<Element> {
        if !isOnQueue {
            var result = ContiguousArray<Element>()
            queue.sync { result = self.array }
            return result
        }
        return array
    }
    
    func contains(where package: (Element) -> Bool) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(where: package) }
            return result
        }
        return array.contains(where: package)
    }
    
    func setTo(_ packages: ContiguousArray<Element>) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array = packages
            }
        } else {
            self.array = packages
        }
    }
    
    func append(_ package: Element) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.append(package)
            }
        } else {
            self.array.append(package)
        }
    }
    
    func removeAll() {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                self.array.removeAll()
            }
        } else {
            self.array.removeAll()
        }
    }
    
    func removeAll(package: @escaping (Element) -> Bool) {
        if !isOnQueue {
            queue.async(flags: .barrier) {
                while let index = self.array.firstIndex(where: package) {
                    self.array.remove(at: index)
                }
            }
        } else {
            while let index = self.array.firstIndex(where: package) {
                self.array.remove(at: index)
            }
        }
    }
    
    func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        if !isOnQueue {
            var result = [ElementOfResult]()
            queue.sync { result = self.array.map(transform) }
            return result
        } else {
            return array.map(transform)
        }
    }
}

extension SafeContiguousArray where Element: Equatable {
    func contains(_ element: Element) -> Bool {
        if !isOnQueue {
            var result = false
            queue.sync { result = self.array.contains(element) }
            return result
        }
        return self.array.contains(element)
    }
}

// MARK: SafeDictionary
final public class SafeDictionary<Key: Hashable, Value> {
    public typealias Element = (key: Key, value: Value)
    
    private var dict: Dictionary<Key, Value>
    private var queue: DispatchQueue
    private var key: DispatchSpecificKey<Int>
    private var context: Int
    
    public var isOnQueue: Bool {
        DispatchQueue.getSpecific(key: key) == context
    }
    
    public init(_ dict: Dictionary<Key, Value> = [:], queue: DispatchQueue, key: DispatchSpecificKey<Int>, context: Int) {
        self.dict = dict
        self.queue = queue
        self.key = key
        self.context = context
    }
}
