struct GlanceState {
    var tick: UInt32 = 0

    mutating func advance() {
        tick &+= 1
    }

    func birdY(height: UInt16) -> UInt16 {
        let space = height > birdHeight ? height - birdHeight : 0
        let amplitude = min(space / 2, 3)
        let phase = UInt16(tick % 4)
        switch phase {
        case 1: return space / 2 + amplitude
        case 3: return space / 2 - amplitude
        default: return space / 2
        }
    }
}

// C++ provides storage; Swift owns its initialization and all state transitions.
@_cdecl("swift_glance_initialize")
public func initializeGlance(_ tick: UnsafeMutablePointer<UInt32>) {
    tick.pointee = 0
}

@_cdecl("swift_glance_advance")
public func advanceGlance(_ tick: UnsafeMutablePointer<UInt32>) {
    var state = GlanceState(tick: tick.pointee)
    state.advance()
    tick.pointee = state.tick
}

@_cdecl("swift_glance_tick")
public func glanceTick(_ tick: UnsafePointer<UInt32>) -> UInt32 {
    tick.pointee
}

@_cdecl("swift_bird_width")
public func swiftBirdWidth() -> UInt16 { birdWidth }

@_cdecl("swift_bird_height")
public func swiftBirdHeight() -> UInt16 { birdHeight }

@_cdecl("swift_bird_y")
public func swiftBirdY(_ tick: UnsafePointer<UInt32>, _ height: UInt16) -> UInt16 {
    GlanceState(tick: tick.pointee).birdY(height: height)
}
