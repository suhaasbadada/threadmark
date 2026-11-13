// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ThreadmarkCompanion",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CompanionKit", targets: ["CompanionKit"]),
        .executable(name: "ThreadmarkCompanion", targets: ["ThreadmarkCompanion"]),
        .executable(name: "CompanionTestProcess", targets: ["CompanionTestProcess"]),
    ],
    targets: [
        .target(name: "CompanionKit"),
        .executableTarget(name: "ThreadmarkCompanion", dependencies: ["CompanionKit"]),
        .executableTarget(name: "CompanionTestProcess"),
        .testTarget(name: "CompanionKitTests", dependencies: ["CompanionKit"]),
    ]
)
