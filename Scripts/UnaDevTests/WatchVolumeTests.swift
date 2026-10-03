import Testing

@testable import UnaDev

@Test func mountedWatch() throws {
  #expect(try watchVolume(in: "/dev/disk4s1 on /Volumes/UNA WATCH (msdos, local)") == "/Volumes/UNA WATCH")
  #expect(try watchVolume(in: "/dev/disk4s1 on /Volumes/UNA WATCH 12 (msdos, local)") == "/Volumes/UNA WATCH 12")
}

@Test func missingOrUnrelatedVolumes() {
  for mounts in [
    "", "/dev/disk1 on / (apfs)", "/dev/disk4 on /Volumes/UNA WATCH backup (msdos)",
    "/dev/disk4 on /Volumes/UNA WATCH  (msdos)",
  ] {
    #expect(throws: ToolError.self) { try watchVolume(in: mounts) }
  }
}

@Test func ambiguousWatches() {
  let mounts = "/dev/disk4 on /Volumes/UNA WATCH (msdos)\n/dev/disk5 on /Volumes/UNA WATCH 1 (msdos)"
  #expect(throws: ToolError.self) { try watchVolume(in: mounts) }
}
