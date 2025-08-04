// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LRUCache",
    platforms: [
        .iOS(.v15),
        .macOS(.v14),
        .tvOS(.v15),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "LRUCache", targets: ["LRUCache"]),
    ],
    targets: [
        .target(name: "LRUCache", path: "Sources"),
        .testTarget(name: "LRUCacheTests", dependencies: ["LRUCache"], path: "Tests"),
    ]
)
