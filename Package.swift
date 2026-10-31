// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cyto",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Cyto",
            targets: ["Cyto"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Cyto",
            dependencies: [],
            path: "Sources/Cyto"
        )
    ]
)
