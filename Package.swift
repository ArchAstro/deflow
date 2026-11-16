// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Deflow",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "DeflowCore"),
        .executableTarget(name: "Deflow", dependencies: ["DeflowCore"]),
        .testTarget(name: "DeflowCoreTests", dependencies: ["DeflowCore"]),
    ],
    swiftLanguageModes: [.v5]
)
