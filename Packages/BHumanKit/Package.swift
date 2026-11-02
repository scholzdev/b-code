// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BHumanKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BHumanKit", targets: ["BHumanKit"])
    ],
    targets: [
        .target(name: "BHumanKit"),
        .testTarget(name: "BHumanKitTests", dependencies: ["BHumanKit"])
    ]
)
