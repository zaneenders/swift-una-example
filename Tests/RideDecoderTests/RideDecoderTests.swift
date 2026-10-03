import Foundation
import Testing

@testable import RideDecoder

private func record(timestamp: UInt64, kind: UInt32 = 1, valid: UInt32 = 1) -> Data {
  var bytes = Data()
  func append(_ value: UInt64, count: Int) {
    for index in 0..<count {
      bytes.append(UInt8(truncatingIfNeeded: value >> (index * 8)))
    }
  }
  append(timestamp, count: 8)
  append(UInt64(kind), count: 4)
  append(UInt64(valid), count: 4)
  for value: Float in [1, -2, 0.5, 0, 0, 0] {
    append(UInt64(value.bitPattern), count: 4)
  }
  return bytes
}

@Test func recordDecoding() throws {
  let sample = try RideRecord(bytes: record(timestamp: .max, kind: 3, valid: 0))
  #expect(sample.timestamp == .max)
  #expect(sample.values == [1, -2, 0.5, 0, 0, 0])
  #expect(sample.csv.hasPrefix("18446744073709551615,location,0,1.0,-2.0,0.5"))
  #expect(throws: DecodeError.self) { try RideRecord(bytes: record(timestamp: 0, kind: 99)) }
  #expect(throws: DecodeError.self) { try RideRecord(bytes: record(timestamp: 0, valid: 2)) }
}

@Test func streamingShortReads() throws {
  let bytes =
    Data("MTBLOG01".utf8) + record(timestamp: 1000)
    + record(timestamp: 21000) + record(timestamp: 41000)
  var offset = 0
  var output = ""
  let summaries = try decodeRide(
    read: { requested in
      let end = min(offset + min(requested, 3), bytes.count)
      defer { offset = end }
      return bytes.subdata(in: offset..<end)
    }, write: { output += $0 })
  #expect(summaries[1]?.count == 3)
  #expect(summaries[1]?.meanInterval == 20000)
  #expect(output.split(separator: "\n").count == 4)
}

@Test func malformedFiles() {
  for bytes in [Data("bad".utf8), Data("MTBLOG01".utf8) + Data([0])] {
    var offset = 0
    #expect(throws: DecodeError.self) {
      try decodeRide(
        read: { count in
          let end = min(offset + count, bytes.count)
          defer { offset = end }
          return bytes.subdata(in: offset..<end)
        }, write: { _ in })
    }
  }
}

@Test func duplicateAndReorderedTimestamps() {
  var summary = SensorSummary()
  for timestamp: UInt64 in [100, 100, 90, 110] { summary.add(timestamp) }
  #expect(summary.count == 4)
  #expect(summary.intervalCount == 1)
  #expect(summary.meanInterval == 20)
}

private func sampleFIT() -> Data {
  var body = Data([0x60, 0, 0, 0, 255, 0, 9])
  for field: UInt8 in 0..<9 {
    body.append(contentsOf: [field, field == 0 ? 8 : 4, 0])
  }
  body.append(0)
  body.append(record(timestamp: 12345, kind: 6))
  var file = Data([14, 32, 0, 0])
  for shift in stride(from: 0, to: 32, by: 8) {
    file.append(UInt8(truncatingIfNeeded: body.count >> shift))
  }
  file.append(contentsOf: Array(".FIT".utf8) + [0, 0])
  file.append(body)
  var crc: UInt16 = 0
  for byte in file {
    var value = UInt16(byte)
    for _ in 0..<8 {
      let bit = (crc ^ value) & 1
      crc >>= 1
      if bit != 0 { crc ^= 0xA001 }
      value >>= 1
    }
  }
  file.append(UInt8(truncatingIfNeeded: crc))
  file.append(UInt8(truncatingIfNeeded: crc >> 8))
  return file
}

@Test func fitSampleAndCRC() throws {
  func decode(_ bytes: Data) throws -> [UInt32: SensorSummary] {
    var offset = 0
    return try decodeRide(
      read: { count in
        let end = min(offset + count, bytes.count)
        defer { offset = end }
        return bytes.subdata(in: offset..<end)
      }, write: { _ in })
  }
  let bytes = sampleFIT()
  #expect(try decode(bytes)[6]?.count == 1)
  var corrupt = bytes
  corrupt[corrupt.count - 1] ^= 1
  #expect(throws: DecodeError.self) { try decode(corrupt) }
  #expect(throws: DecodeError.self) { try decode(Data(bytes.dropLast())) }
}
