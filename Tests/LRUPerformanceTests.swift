//
//  LRUPerformanceTests.swift
//  LRUCacheTests
//
//  Created by Nick Lockwood on 05/08/2021.
//  Copyright © 2021 Nick Lockwood. All rights reserved.
//

import LRUCache
import XCTest

class LRUPerformanceTests: XCTestCase {
    let iterations = 10000

    func testInsertionPerformance() {
        measure {
            let cache = LRUCache<Int, Int>()
            for i in 0 ..< iterations {
                cache.setValue(i, forKey: i)
            }
        }
    }

    func testLookupPerformance() {
        let cache = LRUCache<Int, Int>()
        for i in 0 ..< iterations {
            cache.setValue(i, forKey: i)
        }
        measure {
            for i in 0 ..< iterations {
                _ = cache.value(forKey: i)
            }
        }
    }

    func testRemovalPerformance() {
        let cache = LRUCache<Int, Int>()
        for i in 0 ..< iterations {
            cache.setValue(i, forKey: i)
        }
        measure {
            for i in 0 ..< iterations {
                _ = cache.removeValue(forKey: i)
            }
        }
    }

    func testOverflowInsertionPerformance() {
        measure {
            let cache = LRUCache<Int, Int>(countLimit: 1000)
            for i in 0 ..< iterations {
                cache.setValue(i, forKey: i)
            }
        }
    }
}
