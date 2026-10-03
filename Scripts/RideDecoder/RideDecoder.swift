import Foundation

struct DecodeError: Error, CustomStringConvertible {
  let description: String
}

struct RideRecord {
  let timestamp: UInt64
  let kind: UInt32
  let valid: UInt32
  let values: [Float]

  static let names: [UInt32: String] = [
    1: "acceleration", 2: "gyroscope", 3: "location", 4: "speed",
    5: "pressure", 6: "magnetic", 7: "distance", 8: "clock",
  ]

  init(bytes: Data) throws {
    guard bytes.count == 40 else {
      throw DecodeError(description: "Truncated final record; preceding CSV rows remain usable")
    }
    let bytes = Array(bytes)
    func word(_ offset: Int) -> UInt32 {
      (0..<4).reduce(0) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
    }
    timestamp = UInt64(word(0)) | UInt64(word(4)) << 32
    kind = word(8)
    valid = word(12)
    guard Self.names[kind] != nil, valid <= 1 else {
      throw DecodeError(description: "Invalid record type or validity flag")
    }
    values = (0..<6).map { Float(bitPattern: word(16 + $0 * 4)) }
  }

  var csv: String {
    ([String(timestamp), Self.names[kind]!, String(valid)] + values.map { String($0) })
      .joined(separator: ",") + "\n"
  }
}

struct SensorSummary {
  var count: UInt64 = 0
  var previous: UInt64?
  var minimumInterval: UInt64?
  var maximumInterval: UInt64 = 0
  var intervalCount: UInt64 = 0
  var meanInterval: Double = 0

  mutating func add(_ timestamp: UInt64) {
    count += 1
    if let previous, timestamp > previous {
      let delta = timestamp - previous
      minimumInterval = min(minimumInterval ?? delta, delta)
      maximumInterval = max(maximumInterval, delta)
      intervalCount += 1
      meanInterval += (Double(delta) - meanInterval) / Double(intervalCount)
    }
    previous = timestamp
  }
}

func decodeRide(
  read: (Int) throws -> Data,
  write: (String) throws -> Void
) throws -> [UInt32: SensorSummary] {
  var crc: UInt16 = 0
  func updateCRC(_ byte: UInt8) {
    var value = UInt16(byte)
    for _ in 0..<8 {
      let bit = (crc ^ value) & 1
      crc >>= 1
      if bit != 0 { crc ^= 0xA001 }
      value >>= 1
    }
  }
  // FileHandle can return short reads; assemble only one fixed-size record.
  func readExactly(_ size: Int) throws -> Data {
    var bytes = Data()
    while bytes.count < size {
      let chunk = try read(size - bytes.count)
      if chunk.isEmpty { break }
      for byte in chunk { updateCRC(byte) }
      bytes.append(chunk)
    }
    return bytes
  }
  let header = try readExactly(8)
  if header != Data("MTBLOG01".utf8) {
    guard header.count == 8, header[0] == 14,
      try readExactly(6).prefix(4) == Data(".FIT".utf8)
    else {
      throw DecodeError(description: "Unsupported ride log header")
    }
    let length = (0..<4).reduce(UInt32(0)) { $0 | UInt32(header[4 + $1]) << ($1 * 8) }
    guard length > 0 else {
      throw DecodeError(description: "Unfinalized FIT file; stop recording cleanly first")
    }
    let summaries = try decodeFitSamples(length: Int(length), read: readExactly, write: write)
    guard crc == 0 else { throw DecodeError(description: "FIT CRC mismatch") }
    return summaries
  }
  try write("timestamp_us,sensor,valid,a,b,c,d,e,f\n")
  var summaries: [UInt32: SensorSummary] = [:]
  while true {
    let bytes = try readExactly(40)
    if bytes.isEmpty { break }
    let record = try RideRecord(bytes: bytes)
    try write(record.csv)
    summaries[record.kind, default: SensorSummary()].add(record.timestamp)
  }
  return summaries
}

private func decodeFitSamples(
  length: Int, read: (Int) throws -> Data, write: (String) throws -> Void
) throws -> [UInt32: SensorSummary] {
  struct Definition {
    let global: UInt16
    let nativeSize: Int
    let developerFields: [(UInt8, Int, UInt8)]
    var size: Int { nativeSize + developerFields.reduce(0) { $0 + $1.1 } }
  }
  var remaining = length
  func take(_ count: Int) throws -> Data {
    guard count <= remaining else { throw DecodeError(description: "FIT record exceeds data section") }
    let bytes = try read(count)
    guard bytes.count == count else { throw DecodeError(description: "Truncated FIT data") }
    remaining -= count
    return bytes
  }
  var definitions: [UInt8: Definition] = [:]
  var summaries: [UInt32: SensorSummary] = [:]
  try write("timestamp_us,sensor,valid,a,b,c,d,e,f\n")
  while remaining > 0 {
    let header = try take(1)[0]
    guard header & 0x80 == 0 else {
      throw DecodeError(description: "Compressed timestamps not supported by this logger decoder")
    }
    let local = header & 15
    if header & 0x40 != 0 {
      let prefix = try take(5)
      guard prefix[1] == 0 else { throw DecodeError(description: "Expected little-endian FIT definition") }
      let global = UInt16(prefix[2]) | UInt16(prefix[3]) << 8
      let fields = try take(Int(prefix[4]) * 3)
      var size = 0
      for offset in stride(from: 0, to: fields.count, by: 3) { size += Int(fields[offset + 1]) }
      var developers: [(UInt8, Int, UInt8)] = []
      if header & 0x20 != 0 {
        let count = try take(1)[0]
        let fields = try take(Int(count) * 3)
        for offset in stride(from: 0, to: fields.count, by: 3) {
          developers.append((fields[offset], Int(fields[offset + 1]), fields[offset + 2]))
        }
      }
      definitions[local] = Definition(global: global, nativeSize: size, developerFields: developers)
    } else {
      guard let definition = definitions[local] else { throw DecodeError(description: "Undefined FIT local message") }
      let bytes = try take(definition.size)
      if definition.global == 0xFF00 {
        let fields = definition.developerFields
        guard definition.nativeSize == 0, fields.count == 9,
          fields.enumerated().allSatisfy({ index, field in
            field.0 == UInt8(index) && field.1 == (index == 0 ? 8 : 4) && field.2 == 0
          })
        else { throw DecodeError(description: "Unsupported MTB sample schema") }
        let record = try RideRecord(bytes: bytes)
        try write(record.csv)
        summaries[record.kind, default: SensorSummary()].add(record.timestamp)
      }
    }
  }
  guard try read(2).count == 2 else { throw DecodeError(description: "Missing FIT CRC") }
  return summaries
}
