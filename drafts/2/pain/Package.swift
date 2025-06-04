// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "utility",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "utility",
            dependencies: [
                .product(name: "Socket", package: "BlueSocket")
            ]),
    ]
)
