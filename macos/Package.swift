// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LumaMD",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "LumaMDCore", targets: ["LumaMDCore"]),
        .library(name: "LumaMDMac", targets: ["LumaMDMac"]),
        .executable(name: "LumaMD", targets: ["LumaMDApp"]),
    ],
    targets: [
        .target(
            name: "XCTest"
        ),
        .target(
            name: "LumaMDCore"
        ),
        .target(
            name: "LumaMDMac",
            dependencies: ["LumaMDCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
            ]
        ),
        .executableTarget(
            name: "LumaMDApp",
            dependencies: ["LumaMDMac"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WebKit"),
            ]
        ),
        .target(
            name: "LumaMDCoreTests",
            dependencies: ["LumaMDCore", "XCTest"],
            path: "Tests/LumaMDCoreTests",
            resources: [
                .process("Fixtures"),
            ]
        ),
        .target(
            name: "LumaMDMacTests",
            dependencies: ["LumaMDMac", "LumaMDCore", "XCTest"],
            path: "Tests/LumaMDMacTests"
        ),
        .executableTarget(
            name: "LumaMDCoreTestRunner",
            dependencies: ["LumaMDCoreTests"],
            path: "TestRunners/Core"
        ),
        .executableTarget(
            name: "LumaMDMacTestRunner",
            dependencies: ["LumaMDMacTests"],
            path: "TestRunners/Mac"
        ),
        .testTarget(
            name: "LumaMDSwiftPMTests",
            dependencies: ["XCTest"],
            path: "Tests/LumaMDSwiftPMTests"
        ),
    ]
)
