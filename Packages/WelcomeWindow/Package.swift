// swift-tools-version: 6.0.0

import PackageDescription

let package = Package(
    name: "WelcomeWindow",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .library(
            name: "WelcomeWindow",
            targets: ["WelcomeWindow"]
        ),
    ],
    targets: [
        .target(name: "WelcomeWindow"),
        .testTarget(name: "WelcomeWindowTests", dependencies: ["WelcomeWindow"])
    ]
)
