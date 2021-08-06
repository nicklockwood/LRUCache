//
//  LRUCache.swift
//  LRUCache
//
//  Created by Nick Lockwood on 05/08/2021.
//  Copyright © 2021 Nick Lockwood. All rights reserved.
//
//  Distributed under the permissive MIT license
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/LRUCache
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

#if canImport(UIKit)
import UIKit

/// Notification that cache should be cleared
public let LRUCacheMemoryWarningNotification: NSNotification.Name =
    UIApplication.didReceiveMemoryWarningNotification

#else

/// Notification that cache should be cleared
public let LRUCacheMemoryWarningNotification: NSNotification.Name =
    .init("LRUCacheMemoryWarningNotification")

#endif

public final class LRUCache<Key: Hashable, Value> {
    private final class Container {
        var value: Value
        var sequenceNumber: Int
        var cost: Int
        var key: Key

        init(value: Value, sequenceNumber: Int, cost: Int, key: Key) {
            self.value = value
            self.sequenceNumber = sequenceNumber
            self.cost = cost
            self.key = key
        }
    }

    private var sequenceNumber: Int = 0
    private var values: [Key: Container] = [:]
    private let lock: NSLock = .init()
    private var token: AnyObject?
    private let notificationCenter: NotificationCenter

    /// The current total cost of values in the cache
    public private(set) var totalCost: Int = 0

    /// The maximum total cost permitted
    public var totalCostLimit: Int {
        didSet { clean() }
    }

    /// The maximum number of values permitted
    public var countLimit: Int {
        didSet { clean() }
    }

    /// Initialize the cache with the specified `totalCostLimit` and `countLimit`
    public init(totalCostLimit: Int = .max, countLimit: Int = .max,
                notificationCenter: NotificationCenter = .default)
    {
        self.totalCostLimit = totalCostLimit
        self.countLimit = countLimit
        self.notificationCenter = notificationCenter

        self.token = notificationCenter.addObserver(
            forName: LRUCacheMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.removeAllValues()
        }
    }

    deinit {
        if let token = token {
            notificationCenter.removeObserver(token)
        }
    }
}

public extension LRUCache {
    /// The number of values currently stored in the cache
    var count: Int {
        values.count
    }

    /// Is the cache empty?
    var isEmpty: Bool {
        values.isEmpty
    }

    /// Insert a value into the cache with optional `cost`
    func setValue(_ value: Value?, forKey key: Key, cost: Int = 0) {
        guard let value = value else {
            removeValue(forKey: key)
            return
        }
        lock.lock()
        if let container = values[key] {
            container.value = value
            container.sequenceNumber = sequenceNumber
            totalCost -= container.cost
            container.cost = cost
        } else {
            values[key] = Container(
                value: value,
                sequenceNumber: sequenceNumber,
                cost: cost,
                key: key
            )
        }
        sequenceNumber += 1
        totalCost += cost
        lock.unlock()
        clean()
    }

    /// Remove a value  from the cache and return it
    @discardableResult func removeValue(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard let container = values.removeValue(forKey: key) else {
            return nil
        }
        totalCost -= container.cost
        return container.value
    }

    /// Fetch a value from the cache
    func value(forKey key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        if let container = values[key] {
            container.sequenceNumber = sequenceNumber
            sequenceNumber += 1
            return container.value
        }
        return nil
    }

    /// Remove all values from the cache
    func removeAllValues() {
        lock.lock()
        values.removeAll()
        lock.unlock()
    }
}

private extension LRUCache {
    func clean() {
        lock.lock()
        defer { lock.unlock() }
        guard totalCost > totalCostLimit || count > countLimit else {
            return
        }
        var lru = ArraySlice(values.values.sorted(by: {
            $0.sequenceNumber < $1.sequenceNumber
        }))
        while totalCost > totalCostLimit / 2 || count > countLimit / 2,
              let container = lru.popFirst()
        {
            values.removeValue(forKey: container.key)
            totalCost -= container.cost
        }
    }
}
