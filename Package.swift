// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Speak2",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Speak2", targets: ["Speak2"]),
        .library(name: "Speak2Kit", targets: ["Speak2Kit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.8.0"),
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.13.2"),
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "Speak2",
            dependencies: [
                "Speak2Kit",
                "KeyboardShortcuts",
                "FluidAudio",
            ],
            path: "Sources/Speak2"
        ),
        .target(
            name: "Speak2Kit",
            path: "Sources/Speak2Kit"
        ),
        .testTarget(
            name: "Speak2KitTests",
            dependencies: [
                "Speak2Kit",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/Speak2KitTests"
        ),
    ]
)
