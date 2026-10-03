// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BirdGenerator",
    platforms: [.macOS(.v10_15)],
    dependencies: [
        .package(url: "https://github.com/tayloraswift/swift-png", from: "4.5.0")
    ],
    targets: [
        .executableTarget(
            name: "BirdGenerator",
            dependencies: [.product(name: "PNG", package: "swift-png")],
            path: ".",
            exclude: ["python"],
            sources: ["generate-swift-bird.swift"]
        )
    ]
)
