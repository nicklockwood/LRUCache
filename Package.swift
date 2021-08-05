// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "LRUCache",
    products: [
        .library(name: "LRUCache", targets: ["LRUCache"]),
    ],
    targets: [
        .target(name: "LRUCache", path: "Sources"),
        .testTarget(name: "LRUCacheTests", dependencies: ["LRUCache"], path: "Tests"),
    ]
)
