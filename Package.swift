// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SceytChatUIKit",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SceytChatUIKit",
            targets: ["SceytChatUIKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sceyt/sceyt-chat-ios-sdk.git", .upToNextMajor(from: "1.5.4")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SceytChatUIKit",
            dependencies: [.product(name: "SceytChat", package: "sceyt-chat-ios-sdk")],
            resources: [.copy("Database/SceytChatModel.xcdatamodeld"), .process("Resources")]
        ),
        
        .testTarget(
            name: "SceytChatUIKitTests",
            dependencies: ["SceytChatUIKit"]),
    ]
)
