// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "UnaTools",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(url: "https://github.com/tayloraswift/swift-png", from: "4.5.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "1.0.0")),
  ],
  targets: [
    .executableTarget(
      name: "BirdGenerator",
      dependencies: [.product(name: "PNG", package: "swift-png")],
      path: "Scripts",
      exclude: ["python", "UnaDev", "UnaDevTests"],
      sources: ["generate-swift-bird.swift"]
    ),
    .executableTarget(
      name: "UnaDev",
      dependencies: [.product(name: "Subprocess", package: "swift-subprocess")],
      path: "Scripts/UnaDev"
    ),
    .testTarget(name: "UnaDevTests", dependencies: ["UnaDev"], path: "Scripts/UnaDevTests"),
  ]
)
