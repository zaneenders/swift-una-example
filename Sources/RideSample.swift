// Fixed 40-byte, little-endian records; unused channels are zero.
@c(swift_ride_encode)
public func encodeRideSample(
  _ destination: UnsafeMutablePointer<UInt8>, _ timestamp: UInt64,
  _ kind: UInt32, _ valid: UInt32,
  _ a: Float, _ b: Float, _ c: Float, _ d: Float, _ e: Float, _ f: Float
) {
  var bytes = MutableSpan(_unsafeStart: destination, count: 40)
  for index in 0..<8 {
    bytes[index] = UInt8(truncatingIfNeeded: timestamp >> (index * 8))
  }
  storeWord(kind, at: 8, into: &bytes)
  let finite =
    a.isFinite && b.isFinite && c.isFinite
    && d.isFinite && e.isFinite && f.isFinite
  storeWord(valid != 0 && finite ? 1 : 0, at: 12, into: &bytes)
  storeWord(a.bitPattern, at: 16, into: &bytes)
  storeWord(b.bitPattern, at: 20, into: &bytes)
  storeWord(c.bitPattern, at: 24, into: &bytes)
  storeWord(d.bitPattern, at: 28, into: &bytes)
  storeWord(e.bitPattern, at: 32, into: &bytes)
  storeWord(f.bitPattern, at: 36, into: &bytes)
}

private func storeWord(_ value: UInt32, at offset: Int, into bytes: inout MutableSpan<UInt8>) {
  for index in 0..<4 {
    bytes[offset + index] = UInt8(truncatingIfNeeded: value >> (index * 8))
  }
}
