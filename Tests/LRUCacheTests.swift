//
//  LRUCacheTests.swift
//  LRUCacheTests
//
//  Created by Nick Lockwood on 05/08/2021.
//  Copyright © 2021 Nick Lockwood. All rights reserved.
//

import LRUCache
import XCTest

#if canImport(UIKit)
import UIKit
#endif

class LRUCacheTests: XCTestCase {
    func testCountLimit() {
        let cache = LRUCache<Int, Int>(countLimit: 3)
        cache.setValue(0, forKey: 0)
        XCTAssertNotNil(cache.value(forKey: 0))
        cache.setValue(1, forKey: 1)
        cache.setValue(2, forKey: 2)
        cache.setValue(3, forKey: 3)
        XCTAssertNil(cache.value(forKey: 0))
        XCTAssertNil(cache.value(forKey: 1))
        XCTAssertNil(cache.value(forKey: 2))
        XCTAssertNotNil(cache.value(forKey: 3))
        XCTAssertEqual(cache.count, 1)
    }

    func testCostLimit() {
        let cache = LRUCache<Int, Int>(totalCostLimit: 4)
        cache.setValue(0, forKey: 0, cost: 1)
        cache.setValue(1, forKey: 1, cost: 1)
        cache.setValue(2, forKey: 2, cost: 1)
        XCTAssertNotNil(cache.value(forKey: 0))
        XCTAssertEqual(cache.count, 3)
        XCTAssertEqual(cache.totalCost, 3)
        cache.setValue(3, forKey: 3, cost: 2)
        XCTAssertNil(cache.value(forKey: 0))
        XCTAssertNil(cache.value(forKey: 1))
        XCTAssertNil(cache.value(forKey: 2))
        XCTAssertNotNil(cache.value(forKey: 3))
        XCTAssertEqual(cache.count, 1)
        XCTAssertEqual(cache.totalCost, 2)
    }

    func testAdjustCountLimit() {
        let cache = LRUCache<Int, Int>(totalCostLimit: 2)
        cache.setValue(0, forKey: 0, cost: 1)
        cache.setValue(1, forKey: 1, cost: 1)
        cache.countLimit = 1
        XCTAssertNil(cache.value(forKey: 0))
        XCTAssert(cache.isEmpty)
    }

    func testAdjustCostLimit() {
        let cache = LRUCache<Int, Int>(totalCostLimit: 3)
        cache.setValue(0, forKey: 0, cost: 1)
        cache.setValue(1, forKey: 1, cost: 1)
        cache.setValue(2, forKey: 2, cost: 1)
        cache.totalCostLimit = 2
        XCTAssertNil(cache.value(forKey: 0))
        XCTAssertEqual(cache.count, 1)
        cache.totalCostLimit = 0
        XCTAssert(cache.isEmpty)
    }

    func testRemoveValue() {
        let cache = LRUCache<Int, Int>(totalCostLimit: 2)
        cache.setValue(0, forKey: 0)
        cache.setValue(1, forKey: 1)
        XCTAssertEqual(cache.removeValue(forKey: 0), 0)
        XCTAssertEqual(cache.count, 1)
        XCTAssertNil(cache.removeValue(forKey: 0))
        cache.setValue(nil, forKey: 1)
        XCTAssert(cache.isEmpty)
    }

    func testReplaceValue() {
        let cache = LRUCache<Int, Int>()
        cache.setValue(0, forKey: 0, cost: 5)
        XCTAssertEqual(cache.value(forKey: 0), 0)
        XCTAssertEqual(cache.totalCost, 5)
        cache.setValue(1, forKey: 0, cost: 3)
        XCTAssertEqual(cache.value(forKey: 0), 1)
        XCTAssertEqual(cache.totalCost, 3)
        cache.setValue(2, forKey: 0, cost: 7)
        XCTAssertEqual(cache.value(forKey: 0), 2)
        XCTAssertEqual(cache.totalCost, 7)
    }

    #if canImport(UIKit)
    func testMemoryWarning() {
        let cache = LRUCache<Int, Int>()
        for i in 0 ..< 100 {
            cache.setValue(i, forKey: i)
        }
        XCTAssertEqual(cache.count, 100)
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        XCTAssert(cache.isEmpty)
    }
    
    func testNotificationObserverIsRemoved() {
        final class TestNotificationCenter: NotificationCenter {
            private(set) var observersCount = 0
            
            override func addObserver(
                forName name: NSNotification.Name?,
                object obj: Any?,
                queue: OperationQueue?,
                using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
                defer { observersCount += 1 }
                return super.addObserver(forName: name, object: obj, queue: queue, using: block)
            }
            
            override func removeObserver(_ observer: Any) {
                super.removeObserver(observer)
                observersCount -= 1
            }
        }
        
        let notificationCenter = TestNotificationCenter()
        var cache: LRUCache? = LRUCache<Int, Int>(notificationCenter: notificationCenter)
        weak var weakCache = cache
        
        XCTAssertEqual(1, notificationCenter.observersCount)

        cache = nil
        XCTAssertNil(weakCache)
        
        XCTAssertEqual(0, notificationCenter.observersCount)
    }
    #endif
}
