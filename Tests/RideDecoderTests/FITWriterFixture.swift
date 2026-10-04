import Foundation

private struct CommandError: Error {
  let description: String
}

struct FITWriterFixture {
  let directory: URL
  let file: URL

  static func create() throws -> FITWriterFixture {
    let root = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent("ride-fit-roundtrip-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)

    let executable = temporary.appendingPathComponent("writer-test")
    let fixture = temporary.appendingPathComponent("all-streams.fit")
    try run(
      [
        "clang++", "-std=c++17", "-I", "Sources/UnaApp", "-I", "una-sdk/Libs/Header",
        "Tests/UnaAppTests/RideFitWriterTests.cpp", "Sources/UnaApp/RideFitWriter.cpp",
        "una-sdk/Libs/Source/Fit/FitWriter.cpp", "una-sdk/Libs/Source/Fit/FitCrc.cpp",
        "-o", executable.path,
      ], in: root)
    try run([executable.path, fixture.path], in: root)

    return FITWriterFixture(directory: temporary, file: fixture)
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }
}

private func run(_ arguments: [String], in directory: URL) throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
  process.arguments = arguments
  process.currentDirectoryURL = directory
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    throw CommandError(description: "Command failed: \(arguments.joined(separator: " "))")
  }
}
