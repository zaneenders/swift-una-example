// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "UnaTools",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.25.0"),
    .package(
      url: "https://github.com/zaneenders/swift-fit.git",
      revision: "16d9e57a48464e5857c7b49e9a83fde0f8db202a"
    ),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", .upToNextMinor(from: "1.0.0")),
  ],
  targets: [
    .target(name: "RideAnalysis", dependencies: [.product(name: "SwiftFit", package: "swift-fit")]),
    .executableTarget(name: "RideAnalyzer", dependencies: ["RideAnalysis"], exclude: ["README.md"]),
    .executableTarget(
      name: "RideWeb", dependencies: ["RideAnalysis", .product(name: "Hummingbird", package: "hummingbird")],
      exclude: ["README.md"], resources: [.copy("index.html")]),
    .testTarget(name: "RideAnalyzerTests", dependencies: ["RideAnalysis"]),
    .executableTarget(
      name: "UnaDev",
      dependencies: [.product(name: "Subprocess", package: "swift-subprocess")]
    ),
    .executableTarget(
      name: "RideDecoder",
      dependencies: [.product(name: "SwiftFit", package: "swift-fit")]
    ),
    .testTarget(
      name: "RideDecoderTests",
      dependencies: ["RideDecoder", .product(name: "SwiftFit", package: "swift-fit")]
    ),
    .testTarget(name: "UnaDevTests", dependencies: ["UnaDev"]),
  ]
)
