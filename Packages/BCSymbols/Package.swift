// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BCSymbols",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BCSymbols", targets: ["BCSymbols"])
    ],
    targets: [
        .target(name: "BCSymbols"),
        .testTarget(name: "BCSymbolsTests", dependencies: ["BCSymbols"])
    ]
)
