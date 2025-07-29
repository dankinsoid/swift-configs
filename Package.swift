// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-configs",
    products: [
        .library(name: "SwiftConfigs", targets: ["SwiftConfigs"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "SwiftConfigs", dependencies: []),
        .testTarget(name: "SwiftConfigsTests", dependencies: ["SwiftConfigs"]),
    ]
)
