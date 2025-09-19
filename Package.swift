// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LiveParse",
    platforms: [.macOS(.v10_15),
                .iOS(.v14),
                .tvOS(.v14)],
    products: [
        .library(
            name: "LiveParse",
            targets: ["LiveParse"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.8.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.1")),
        .package(url: "https://github.com/daltoniam/Starscream", .upToNextMajor(from: "4.0.6")),
        .package(url: "https://github.com/tsolomko/SWCompression", .upToNextMajor(from: "4.8.6")),
        .package(url: "https://github.com/apple/swift-protobuf.git", .upToNextMajor(from: "1.25.1")),
        .package(url: "https://github.com/pcccccc/YouTubeKit", .upToNextMajor(from: "0.0.3")),
        .package(url: "https://github.com/pcccccc/TarsKit", .upToNextMajor(from: "1.2.0")),
        .package(url: "https://github.com/pcccccc/GMObjC", branch: "master")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LiveParse",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "SwiftyJSON", package: "SwiftyJSON"),
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "SWCompression", package: "SWCompression"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "YouTubeKit", package: "YouTubeKit"),
                .product(name: "TarsKit", package: "TarsKit"),
                .product(name: "GMObjC", package: "GMObjC")
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LiveParseTests",
            dependencies: ["LiveParse"]),
    ]
)

