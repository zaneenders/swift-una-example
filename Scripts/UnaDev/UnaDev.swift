#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation
import Subprocess

struct ToolError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

func watchVolume(in mounts: String) throws -> String {
  let paths = mounts.split(separator: "\n").compactMap { line -> String? in
    guard let start = line.range(of: " on /Volumes/UNA WATCH"),
      let end = line.range(of: " (", range: start.upperBound..<line.endIndex)
    else { return nil }
    let path = String(line[line.index(start.lowerBound, offsetBy: 4)..<end.lowerBound])
    let suffix = path.dropFirst("/Volumes/UNA WATCH".count)
    guard
      suffix.isEmpty
        || (suffix.first == " " && !suffix.dropFirst().isEmpty
          && suffix.dropFirst().allSatisfy({ $0.isASCII && $0.isNumber }))
    else { return nil }
    return path
  }
  guard paths.count == 1 else {
    throw ToolError(
      paths.isEmpty ? "No mounted UNA watch found; nothing copied." : "Multiple watches found; nothing copied.")
  }
  return paths[0]
}

struct Tools {
  let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  let environment: [String: String]

  init(environment: [String: String] = ProcessInfo.processInfo.environment) {
    var environment = environment
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let extra = ["/opt/ST/STM32CubeCLT_1.22.0/GNU-tools-for-STM32/bin", "/opt/homebrew/bin", "\(home)/.cargo/bin"]
    environment["PATH"] = ([environment["PATH"] ?? ""] + extra).joined(separator: ":")
    self.environment = environment
  }

  func executable(_ name: String) throws -> String {
    func isExecutableFile(_ path: String) -> Bool {
      var isDirectory: ObjCBool = false
      return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        && !isDirectory.boolValue && FileManager.default.isExecutableFile(atPath: path)
    }
    if name.contains("/") {
      guard isExecutableFile(name) else { throw ToolError("Not an executable file: \(name)") }
      return name
    }
    for directory in (environment["PATH"] ?? "").split(separator: ":") {
      let path = "\(directory)/\(name)"
      if isExecutableFile(path) { return path }
    }
    throw ToolError("Missing executable: \(name). Install it or add it to PATH.")
  }

  func swiftCompiler() throws -> String {
    try executable(environment["SWIFTC"] ?? "swiftc")
  }

  func run(_ name: String, _ arguments: [String]) async throws {
    let result = try await Subprocess.run(
      .path(.init(try executable(name))), arguments: .init(arguments),
      environment: .custom(
        Dictionary(uniqueKeysWithValues: environment.map { (Environment.Key(stringLiteral: $0.key), $0.value) })),
      workingDirectory: .init(root.path),
      output: .fileDescriptor(.standardOutput, closeAfterSpawningProcess: false),
      error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false)
    )
    guard result.terminationStatus == .exited(0) else {
      throw ToolError("\(name) failed: \(result.terminationStatus)")
    }
  }

  func capture(_ name: String, _ arguments: [String]) async throws -> String {
    let result = try await Subprocess.run(
      .path(.init(try executable(name))), arguments: .init(arguments),
      environment: .custom(
        Dictionary(uniqueKeysWithValues: environment.map { (Environment.Key(stringLiteral: $0.key), $0.value) })),
      workingDirectory: .init(root.path),
      output: .string(limit: 1_048_576),
      error: .fileDescriptor(.standardError, closeAfterSpawningProcess: false)
    )
    guard result.terminationStatus == .exited(0) else {
      throw ToolError("\(name) failed: \(result.terminationStatus)")
    }
    return result.standardOutput
  }

  func checkBuildTools() async throws -> String {
    guard FileManager.default.fileExists(atPath: root.appendingPathComponent("una-sdk/cmake/una-app.cmake").path) else {
      throw ToolError("UNA SDK missing. Run: git submodule update --init")
    }
    for name in ["cmake", "uv", "arm-none-eabi-g++", "rsvg-convert"] {
      print("\(name): \(try executable(name))")
    }
    let compiler = try swiftCompiler()
    let version = try await capture(compiler, ["-version"])
    guard version.contains("Swift version 6.4") else { throw ToolError("Swift 6.4 required; found \(version)") }
    let info = try await capture(
      compiler,
      ["-print-target-info", "-target", "armv8m.main-none-none-eabi", "-enable-experimental-feature", "Embedded"])
    let json = try JSONSerialization.jsonObject(with: Data(info.utf8)) as? [String: Any]
    let paths = json?["paths"] as? [String: Any]
    guard let libraries = paths?["runtimeLibraryPaths"] as? [String],
      let library = libraries.first, FileManager.default.fileExists(atPath: library)
    else {
      throw ToolError(
        "Embedded ARM standard library missing in \(compiler). Set SWIFTC to a swift.org Swift 6.4 compiler.")
    }
    print("Embedded Swift: \(compiler)")
    return compiler
  }

  func build() async throws {
    if !FileManager.default.fileExists(atPath: root.appendingPathComponent("una-sdk/cmake/una-app.cmake").path) {
      try await run("git", ["submodule", "update", "--init", "una-sdk"])
    }
    let compiler = try await checkBuildTools()
    try await run("rsvg-convert", ["Resources/swift-bird.svg", "-o", "Resources/swift-bird.png"])
    try await run("swift", ["run", "BirdGenerator"])
    try await run("cmake", ["-S", ".", "-B", "build", "-DSWIFTC=\(compiler)"])
    try await run("cmake", ["--build", "build", "--parallel", String(ProcessInfo.processInfo.activeProcessorCount)])
  }

  func install() async throws {
    let source = root.appendingPathComponent("build/SwiftUnaExample_1.0.0.uapp")
    guard FileManager.default.fileExists(atPath: source.path) else {
      throw ToolError("Package missing. Run build first.")
    }
    let volume = try watchVolume(in: await capture("/sbin/mount", []))
    let contents = try Data(contentsOf: source)
    // Recheck immediately before touching the volume; a stale /Volumes folder is not a watch.
    guard try watchVolume(in: await capture("/sbin/mount", [])) == volume else {
      throw ToolError("Watch mount changed; nothing copied.")
    }
    let directory = URL(fileURLWithPath: volume).appendingPathComponent("Apps/SwiftUnaExample")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let destination = directory.appendingPathComponent(source.lastPathComponent)
    try contents.write(to: destination)
    guard try Data(contentsOf: destination) == contents else {
      throw ToolError("Installed package verification failed.")
    }
    print("Copied and verified: \(destination.path)")
    print("Eject the watch in Finder, disconnect it, then power it off and back on.")
  }
}

@main
struct UnaDev {
  static func main() async {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      guard arguments.count == 1 else { throw ToolError("Usage: UnaDev build|install|build-install|doctor") }
      let tools = Tools()
      switch arguments[0] {
      case "build": try await tools.build()
      case "install": try await tools.install()
      case "build-install":
        try await tools.build()
        try await tools.install()
      case "doctor":
        _ = try await tools.checkBuildTools()
        let mounts = try await tools.capture("/sbin/mount", [])
        do { print("Watch: \(try watchVolume(in: mounts))") } catch { print("Watch: \(error)") }
      case "--help", "-h": print("Usage: UnaDev build|install|build-install|doctor")
      default: throw ToolError("Unknown command: \(arguments[0]). Use build, install, build-install, or doctor.")
      }
    } catch {
      FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
      exit(1)
    }
  }
}
