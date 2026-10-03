@main
struct RideSampleTests {
  static func main() {
    var bytes = [UInt8](repeating: 0xAA, count: 41)
    bytes.withUnsafeMutableBufferPointer { buffer in
      encodeRideSample(buffer.baseAddress!, 0x0102_0304_0506_0708, 1, 1, 1, -2, 0.5, 0, 0, 0)
    }
    assert(Array(bytes[0..<8]) == [8, 7, 6, 5, 4, 3, 2, 1])
    assert(Array(bytes[8..<16]) == [1, 0, 0, 0, 1, 0, 0, 0])
    assert(Array(bytes[16..<20]) == [0, 0, 128, 63])
    assert(Array(bytes[20..<24]) == [0, 0, 0, 192])
    assert(bytes[40] == 0xAA)
    for value: Float in [.nan, .infinity, -.infinity] {
      bytes.withUnsafeMutableBufferPointer { buffer in
        encodeRideSample(buffer.baseAddress!, 0, 2, 1, value, 0, 0, 0, 0, 0)
      }
      assert(bytes[12] == 0)
    }
    bytes.withUnsafeMutableBufferPointer { buffer in
      encodeRideSample(buffer.baseAddress!, .max, 3, 0, 0, 0, 0, 0, 0, 0)
    }
    assert(bytes.prefix(8).allSatisfy { $0 == 255 })
    assert(bytes[12] == 0)
    print("Ride sample tests passed")
  }
}
