// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftEmoji",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftEmoji",
            targets: ["SwiftEmoji"]
        ),
        .library(
            name: "SwiftEmojiIndex",
            targets: ["SwiftEmojiIndex"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftEmojiIndex",
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "SwiftEmoji",
            dependencies: ["SwiftEmojiIndex"]
        ),
        .executableTarget(
            name: "BuildEmojiIndex",
            dependencies: ["SwiftEmojiIndex"],
            path: "Sources/BuildEmojiIndex"
        ),
        .testTarget(
            name: "SwiftEmojiIndexTests",
            dependencies: ["SwiftEmojiIndex"]
        ),
        .testTarget(
            name: "SwiftEmojiTests",
            dependencies: ["SwiftEmoji"]
        ),
    ]
)
