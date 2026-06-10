// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UniControl",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "UniControlCore",
            targets: ["UniControlCore"]
        ),
        .executable(
            name: "UniControl",
            targets: ["UniControlCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "UniControlCore",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
            ],
            path: "Sources/UniControlCore"
        ),
        .executableTarget(
            name: "UniControlCLI",
            dependencies: ["UniControlCore"],
            path: "Sources/UniControlCLI"
        ),
        .testTarget(
            name: "UniControlCoreTests",
            dependencies: ["UniControlCore"],
            path: "Tests/UniControlCoreTests"
        )
    ]
)
