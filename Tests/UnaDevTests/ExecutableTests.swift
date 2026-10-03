import Foundation
import Testing

@testable import UnaDev

@Test func skipsDirectoriesInExecutableSearch() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  let first = root.appendingPathComponent("first")
  let second = root.appendingPathComponent("second")
  try FileManager.default.createDirectory(at: first.appendingPathComponent("tool"), withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
  let program = second.appendingPathComponent("tool")
  try Data("#!/bin/sh\nexit 0\n".utf8).write(to: program)
  try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: program.path)
  let tools = Tools(environment: ["PATH": "\(first.path):\(second.path)"])
  #expect(try tools.executable("tool") == program.path)
  #expect(try tools.executable(program.path) == program.path)
  #expect(throws: ToolError.self) { try tools.executable(first.appendingPathComponent("tool").path) }
  try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: program.path)
  #expect(throws: ToolError.self) { try tools.executable("tool") }
}

@Test func swiftCompilerUsesPathAndOverride() throws {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: root) }
  try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  let compiler = root.appendingPathComponent("swiftc")
  let override = root.appendingPathComponent("custom-swiftc")
  for file in [compiler, override] {
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
  }
  #expect(try Tools(environment: ["PATH": root.path]).swiftCompiler() == compiler.path)
  #expect(try Tools(environment: ["PATH": root.path, "SWIFTC": override.path]).swiftCompiler() == override.path)
  #expect(throws: ToolError.self) {
    try Tools(environment: ["PATH": root.path, "SWIFTC": root.appendingPathComponent("missing").path]).swiftCompiler()
  }
}
