// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "UnaTools",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(
      url: "https://github.com/zaneenders/swift-fit.git",
      revision: "16d9e57a48464e5857c7b49e9a83fde0f8db202a"
    ),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "1.0.0")),
  ],
  targets: [
    .executableTarget(
      name: "UnaDev",
      dependencies: [.product(name: "Subprocess", package: "swift-subprocess")],
      path: "Scripts/UnaDev"
    ),
    .executableTarget(
      name: "RideDecoder",
      dependencies: [.product(name: "SwiftFit", package: "swift-fit")],
      path: "Scripts/RideDecoder"
    ),
    .testTarget(
      name: "RideDecoderTests",
      dependencies: ["RideDecoder", .product(name: "SwiftFit", package: "swift-fit")],
      path: "Tests/RideDecoderTests"
    ),
    .testTarget(name: "UnaDevTests", dependencies: ["UnaDev"], path: "Tests/UnaDevTests"),
  ]
)
