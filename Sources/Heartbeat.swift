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

@c(swift_glance_initialize)
public func initializeGlance(_ tick: UnsafeMutablePointer<UInt32>) {
  var storage = MutableSpan(_unsafeStart: tick, count: 1)
  storage[0] = 0
}

@c(swift_glance_advance)
public func advanceGlance(_ tick: UnsafeMutablePointer<UInt32>) {
  var storage = MutableSpan(_unsafeStart: tick, count: 1)
  var state = GlanceState(tick: storage[0])
  state.advance()
  storage[0] = state.tick
}

@c(swift_glance_tick)
public func glanceTick(_ tick: UnsafePointer<UInt32>) -> UInt32 {
  let storage = Span(_unsafeStart: tick, count: 1)
  return storage[0]
}

@c(swift_bird_width)
public func swiftBirdWidth() -> UInt16 { birdWidth }

@c(swift_bird_height)
public func swiftBirdHeight() -> UInt16 { birdHeight }

@c(swift_bird_y)
public func swiftBirdY(_ tick: UnsafePointer<UInt32>, _ height: UInt16) -> UInt16 {
  let storage = Span(_unsafeStart: tick, count: 1)
  return GlanceState(tick: storage[0]).birdY(height: height)
}

@c(swift_glance_render_text)
public func renderGlanceText(
  _ context: UnsafeMutableRawPointer,
  _ printText: @convention(c) (UnsafeMutableRawPointer, UnsafePointer<UInt8>, UInt32) -> Void
) {
  let text: StaticString = "zane was here"
  text.withUTF8Buffer { bytes in
    printText(context, bytes.baseAddress!, UInt32(bytes.count))
  }
}
