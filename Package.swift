// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommunicateKit",
    platforms: [
        .iOS(.v10),
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "CommunicateKit",
            targets: ["CommunicateKit"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CommunicateKit",
            dependencies: [],
            path: "Source"),
        .testTarget(
            name: "CommunicateKitTests",
            dependencies: ["CommunicateKit"],
            path: "CommunicateTests"),
    ]
)
