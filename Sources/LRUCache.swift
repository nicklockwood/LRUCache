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
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// A thread-safe least-recently-used cache.
///
/// `LRUCache` stores values by key and evicts the least recently used values
/// first when either `totalCostLimit` or `countLimit` is exceeded. Reading a
/// value with `value(forKey:)` updates its recency, while `hasValue(forKey:)`
/// does not.
///
/// The cache is safe to access from multiple threads. `LRUCache` conforms to
/// `Sendable` when `Value` is also `Sendable`.
///
/// - Parameters:
///   - Key: The type used to identify cached values.
///   - Value: The type of values stored in the cache.
public final class LRUCache<Key: Hashable & Sendable, Value> {
    private var _values: [Key: Container] = [:]
    private var _countLimit: Int
    private var _totalCost: Int = 0
    private var _totalCostLimit: Int
    private unowned(unsafe) var head: Container?
    private unowned(unsafe) var tail: Container?
    private let clearsOnMemoryPressure: Bool
    private let lock: NSLock = .init()

    #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private let memoryPressureSource: DispatchSourceMemoryPressure?
    #endif

    /// Creates a cache with the specified memory limits.
    ///
    /// Values are evicted least-recently-used first when either limit is
    /// exceeded. A cost of zero can be used for values whose cost is unknown,
    /// in which case they will only be evicted when `countLimit` is exceeded.
    ///
    /// - Parameters:
    ///   - totalCostLimit: The maximum total cost of values stored in memory.
    ///     The default is `Int.max`, which is effectively unlimited.
    ///   - countLimit: The maximum number of values stored in memory. The
    ///     default is `Int.max`, which is effectively unlimited.
    ///   - clearsOnMemoryPressure: Whether the cache should be cleared
    ///     when the system reports memory pressure on supported Apple
    ///     platforms. The default is `true`.
    public init(
        totalCostLimit: Int = .max,
        countLimit: Int = .max,
        clearsOnMemoryPressure: Bool = true
    ) {
        self._totalCostLimit = totalCostLimit
        self._countLimit = countLimit
        self.clearsOnMemoryPressure = clearsOnMemoryPressure

        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        if clearsOnMemoryPressure {
            self.memoryPressureSource = DispatchSource
                .makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global())
            memoryPressureSource?.setEventHandler { [weak self] in
                self?.removeAll()
            }
            memoryPressureSource?.resume()
        } else {
            self.memoryPressureSource = nil
        }
        #endif
    }

    deinit {
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS) || os(visionOS)
        self.memoryPressureSource?.cancel()
        #endif
    }
}

/// Conformance that allows caches containing `Sendable` values to be shared
/// across Swift concurrency domains.
extension LRUCache: @unchecked Sendable where Value: Sendable {}

public extension LRUCache {
    /// The current total cost of values stored in memory.
    ///
    /// This is the sum of the `cost` values passed to `setValue(_:forKey:cost:)`
    /// for values that have not been evicted from memory.
    var totalCost: Int {
        atomic { _totalCost }
    }

    /// The maximum total cost permitted in memory.
    ///
    /// Lowering this value immediately evicts least-recently-used values until
    /// the cache is within the new limit. The default value is `Int.max`.
    var totalCostLimit: Int {
        get { atomic { _totalCostLimit } }
        set {
            atomic {
                _totalCostLimit = newValue
                clean()
            }
        }
    }

    /// The number of values currently stored in memory.
    var count: Int {
        atomic { _values.count }
    }

    /// The maximum number of values permitted in memory.
    ///
    /// Lowering this value immediately evicts least-recently-used values until
    /// the cache is within the new limit. The default value is `Int.max`.
    var countLimit: Int {
        get { atomic { _countLimit } }
        set {
            atomic {
                _countLimit = newValue
                clean()
            }
        }
    }

    /// A Boolean value indicating whether the memory cache is empty.
    var isEmpty: Bool {
        atomic { _values.isEmpty }
    }

    /// All keys currently stored in memory, in no particular order.
    var keys: some Collection<Key> {
        atomic { _values.keys }
    }

    /// All values currently stored in memory, in no particular order.
    var values: some Collection<Value> {
        atomic { _values.values.map(\.value) }
    }

    /// All keys currently stored in memory, ordered from least recently used to
    /// most recently used.
    ///
    /// This property walks the cache's internal linked list and is much slower
    /// to compute than `keys`.
    var orderedKeys: [Key] {
        atomic {
            var keys = [Key]()
            keys.reserveCapacity(_values.count)
            var next = head
            while let container = next {
                keys.append(container.key)
                next = container.next
            }
            return keys
        }
    }

    /// All values currently stored in memory, ordered from least recently used
    /// to most recently used.
    ///
    /// This property walks the cache's internal linked list and is much slower
    /// to compute than `values`.
    var orderedValues: [Value] {
        atomic {
            var values = [Value]()
            values.reserveCapacity(_values.count)
            var next = head
            while let container = next {
                values.append(container.value)
                next = container.next
            }
            return values
        }
    }

    /// Inserts or removes a value for the specified key.
    ///
    /// Passing a non-`nil` value stores it in memory, marks it as most recently
    /// used. Passing `nil` removes the value from memory.
    ///
    /// - Parameters:
    ///   - value: The value to cache, or `nil` to remove any existing value for
    ///     `key`.
    ///   - key: The key used to store and retrieve the value.
    ///   - cost: The cost to associate with the value in memory. The default is
    ///     zero.
    func setValue(_ value: Value?, forKey key: Key, cost: Int = 0) {
        guard let value else {
            removeValue(forKey: key)
            return
        }
        atomic {
            if let container = _values[key] {
                container.value = value
                _totalCost += cost - container.cost
                container.cost = cost
                remove(container)
                append(container)
            } else {
                let container = Container(
                    value: value,
                    cost: cost,
                    key: key
                )
                _totalCost += cost
                _values[key] = container
                append(container)
            }
            clean()
        }
    }

    /// Returns whether a value exists for the specified key.
    /// Calling this method does not update the value's recency.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: `true` if a value exists for `key`, otherwise, `false`.
    func hasValue(forKey key: Key) -> Bool {
        atomic { _values[key] != nil }
    }

    /// Returns the value for the specified key and marks it as most recently
    /// used.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The cached value for `key`, or `nil` if no value exists.
    func value(forKey key: Key) -> Value? {
        atomic {
            if let container = _values[key] {
                remove(container)
                append(container)
                return container.value
            }
            return nil
        }
    }

    /// Removes and returns the value for the specified key.
    ///
    /// - Parameter key: The key whose value should be removed.
    /// - Returns: The value removed from memory, or `nil` if no memory value
    ///   existed for `key`.
    @discardableResult func removeValue(forKey key: Key) -> Value? {
        atomic {
            guard let container = _values.removeValue(forKey: key) else {
                return nil
            }
            remove(container)
            _totalCost -= container.cost
            return container.value
        }
    }

    /// Removes all values from the cache.
    func removeAll() {
        atomic {
            _values.removeAll()
            head = nil
            tail = nil
            _totalCost = 0
        }
    }
}

private extension LRUCache {
    final class Container {
        var value: Value
        var cost: Int
        let key: Key
        unowned(unsafe) var prev: Container?
        unowned(unsafe) var next: Container?

        init(value: Value, cost: Int, key: Key) {
            self.value = value
            self.cost = cost
            self.key = key
        }
    }

    /// Atomic access
    #if compiler(>=6.0)
    func atomic<T: Sendable>(_ action: () -> sending T) -> sending T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }
    #endif

    func atomic<T>(_ action: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }

    /// Remove container from list (must be called inside lock)
    func remove(_ container: Container) {
        if head === container {
            head = container.next
        }
        if tail === container {
            tail = container.prev
        }
        container.next?.prev = container.prev
        container.prev?.next = container.next
        container.next = nil
    }

    /// Append container to list (must be called inside lock)
    func append(_ container: Container) {
        assert(container.next == nil)
        if head == nil {
            head = container
        }
        container.prev = tail
        tail?.next = container
        tail = container
    }

    /// Remove expired values (must be called inside lock)
    func clean() {
        while _totalCost > _totalCostLimit || _values.count > _countLimit,
              let container = head
        {
            remove(container)
            _values.removeValue(forKey: container.key)
            _totalCost -= container.cost
        }
    }
}
