// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ditto4Mac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "Ditto4Mac",
            path: "Ditto4Mac",
            exclude: [".idea"]
        ),
        .testTarget(
            name: "Ditto4MacTests",
            dependencies: ["Ditto4Mac"],
            path: "Tests/Ditto4MacTests"
        ),
    ]
)
