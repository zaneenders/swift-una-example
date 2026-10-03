@main
struct GlanceTests {
    static func main() {
        var tick: UInt32 = 99
        initializeGlance(&tick)
        assert(glanceTick(&tick) == 0)
        assert(swiftBirdWidth() == 48 && swiftBirdHeight() == 48)
        var positions: [UInt16] = []
        for _ in 0..<4 {
            positions.append(swiftBirdY(&tick, 60))
            advanceGlance(&tick)
        }
        assert(positions == [6, 9, 6, 3])
        assert(glanceTick(&tick) == 4)
        tick = .max
        advanceGlance(&tick)
        assert(tick == 0)
        for height: UInt16 in [0, 47, 48, 49, 50, 60, .max] {
            for phase: UInt32 in 0..<4 {
                tick = phase
                let y = swiftBirdY(&tick, height)
                assert(UInt32(y) + 48 <= max(UInt32(height), 48))
            }
        }
        var pixels = [UInt8](repeating: 0xAA, count: 2304)
        pixels.withUnsafeMutableBufferPointer { buffer in
            assert(copyBird(buffer.baseAddress!, 2303) == 0)
            assert(buffer.allSatisfy { $0 == 0xAA })
            assert(copyBird(buffer.baseAddress!, 2304) == 2304)
        }
        assert(pixels.contains(0) && pixels.contains(0xC7))
        print("Glance tests passed")
    }
}
