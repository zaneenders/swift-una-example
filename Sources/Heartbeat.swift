@_cdecl("swift_next_tick")
public func nextTick(_ tick: UInt32) -> UInt32 {
    tick &+ 1
}
