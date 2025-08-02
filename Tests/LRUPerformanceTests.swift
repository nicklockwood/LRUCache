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
    let cache = LRUCache<Int, Int>()

    override func setUp() {
        cache.removeAllValues()
        for i in 0 ..< iterations {
            cache.setValue(Int.random(in: .min ... .max), forKey: i)
        }
    }

    func testInsertionPerformance() {
        measure {
            let cache = LRUCache<Int, Int>()
            for i in 0 ..< iterations {
                cache.setValue(Int.random(in: .min ... .max), forKey: i)
            }
        }
    }

    func testLookupPerformance() {
        var values = [Int?](repeating: nil, count: iterations)
        measure {
            for i in 0 ..< iterations {
                values[i] = cache.value(forKey: i)
            }
        }
    }

    func testRemovalPerformance() {
        var values = [Int?](repeating: nil, count: iterations)
        measure {
            for i in 0 ..< iterations {
                values[i] = cache.removeValue(forKey: i)
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
