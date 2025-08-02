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
        cache.removeAll()
        populateCache(cache)
    }

    private func populateCache(_ cache: LRUCache<Int, Int>) {
        for i in 0 ..< iterations {
            cache.setValue(.random(in: .min ... .max), forKey: i)
        }
    }

    func testInsertionPerformance() {
        cache.removeAll()
        measure {
            populateCache(cache)
        }
    }

    func testLookupPerformance() {
        var values = [Int?](repeating: nil, count: iterations)
        measure {
            for i in 0 ..< iterations {
                values[i] = cache.value(forKey: i)
            }
        }
        XCTAssert(values.allSatisfy { $0 != nil })
    }

    func testRemovalPerformance() {
        var caches = [LRUCache<Int, Int>]()
        for _ in 0 ... 50 { // just to be safe
            let cache = LRUCache<Int, Int>()
            populateCache(cache)
            caches.append(cache)
        }
        var values = [Int?](repeating: nil, count: iterations)
        measure {
            let cache = caches.popLast()!
            for i in 0 ..< iterations {
                values[i] = cache.removeValue(forKey: i)
            }
        }
        XCTAssert(values.allSatisfy { $0 != nil })
    }

    func testOverflowInsertionPerformance() {
        cache.removeAll()
        cache.countLimit = 1000
        measure {
            for i in 0 ..< iterations {
                cache.setValue(.random(in: .min ... .max), forKey: i)
            }
        }
        XCTAssertEqual(cache.count, 1000)
    }

    func testKeysPerformance() {
        var keys: (any Collection<Int>)?
        measure {
            for _ in 0 ..< iterations {
                keys = cache.keys
            }
        }
        XCTAssertEqual(keys?.count, iterations)
    }

    func testValuesPerformance() {
        var values: (any Collection<Int>)?
        measure {
            for _ in 0 ..< iterations {
                values = cache.keys
            }
        }
        XCTAssertEqual(values?.count, iterations)
    }

    #if os(macOS) || os(iOS)

    @available(iOS 13.0, *)
    func testOrderedKeysPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        var keys: (any Collection<Int>)?
        measure(options: options) {
            for _ in 0 ..< iterations {
                keys = cache.orderedKeys
            }
        }
        XCTAssertEqual(keys?.count, iterations)
    }

    @available(iOS 13.0, *)
    func testOrderedValuesPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        var values: (any Collection<Int>)?
        measure(options: options) {
            for _ in 0 ..< iterations {
                values = cache.orderedValues
            }
        }
        XCTAssertEqual(values?.count, iterations)
    }

    #endif
}
