//
//  Lock.swift
//  Sileo
//
//  Created by Kabir Oberai on 11/07/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

protocol Lock {
    func mutateWithLock<S, T>(value: inout S, _ execute: (inout S) throws -> T) rethrows -> T
    func withLock<S, T>(value: S, _ execute: (S) throws -> T) rethrows -> T
    func withLock<T>(_ execute: () throws -> T) rethrows -> T
}

extension Lock {
    func withLock<S, T>(value: S, _ execute: (S) throws -> T) rethrows -> T {
        var value = value
        return try mutateWithLock(value: &value) { try execute($0) }
    }

    func withLock<T>(_ execute: () throws -> T) rethrows -> T {
        try withLock(value: (), execute)
    }
}

class LockedResource<Value> {
    let lock: Lock
    var unsafeValue: Value

    init(_ value: Value, lock: Lock) {
        self.unsafeValue = value
        self.lock = lock
    }

    func mutateWithLock<T>(_ execute: (inout Value) throws -> T) rethrows -> T {
        try lock.mutateWithLock(value: &unsafeValue, execute)
    }

    func withLock<T>(_ execute: (Value) throws -> T) rethrows -> T {
        try lock.withLock(value: unsafeValue, execute)
    }
}

class DispatchSemaphoreLock: Lock {
    private let semaphore = DispatchSemaphore(value: 1)
    init() {}

    func mutateWithLock<S, T>(value: inout S, _ execute: (inout S) throws -> T) rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        return try execute(&value)
    }

    func withLock<S, T>(value: S, _ execute: (S) throws -> T) rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        return try execute(value)
    }

    func withLock<T>(_ execute: () throws -> T) rethrows -> T {
        semaphore.wait()
        defer { semaphore.signal() }
        return try execute()
    }
}

class DispatchQueueLock: Lock {
    private let queue: DispatchQueue
    init(label: String, qos: DispatchQoS = .unspecified) {
        queue = DispatchQueue(label: label, qos: qos)
    }

    func mutateWithLock<S, T>(value: inout S, _ execute: (inout S) throws -> T) rethrows -> T {
        try queue.sync { try execute(&value) }
    }

    func withLock<S, T>(value: S, _ execute: (S) throws -> T) rethrows -> T {
        try queue.sync { try execute(value) }
    }

    func withLock<T>(_ execute: () throws -> T) rethrows -> T {
        try queue.sync(execute: execute)
    }
}

class PThreadLock: Lock {
    private var mutex = pthread_mutex_t()
    init(recursive: Bool = false) {
        if recursive {
            var attr = pthread_mutexattr_t()
            pthread_mutexattr_init(&attr)
            pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
            pthread_mutex_init(&mutex, &attr)
        } else {
            pthread_mutex_init(&mutex, nil)
        }
    }

    func mutateWithLock<S, T>(value: inout S, _ execute: (inout S) throws -> T) rethrows -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try execute(&value)
    }

    func withLock<S, T>(value: S, _ execute: (S) throws -> T) rethrows -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try execute(value)
    }

    func withLock<T>(_ execute: () throws -> T) rethrows -> T {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        return try execute()
    }
}
