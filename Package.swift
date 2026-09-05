// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PalmPadCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "PalmPadCore", targets: ["PalmPadCore"])],
    targets: [
        .target(name: "PalmPadCore", path: "Shared", exclude: ["PeerLink.swift"]),
        .testTarget(name: "PalmPadCoreTests", dependencies: ["PalmPadCore"], path: "Tests")
    ]
)
