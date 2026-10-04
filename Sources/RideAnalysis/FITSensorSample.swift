import SwiftFit

enum SensorStream: UInt32, CaseIterable {
  case acceleration = 1
  case gyroscope
  case location
  case speed
  case pressure
  case magnetic
  case distance
  case clock

  var name: String { String(describing: self) }
}

enum SampleValidity: UInt32 {
  case invalid = 0
  case valid = 1
}

enum SensorField: UInt8, CaseIterable {
  case timestamp = 0
  case stream
  case validity
  case a, b, c, d, e, f

  static let channels: [SensorField] = [.a, .b, .c, .d, .e, .f]
}

struct FITSensorSample: Equatable {
  static let messageNumber: UInt16 = 0xFF00
  static let developerIndex: UInt8 = 0

  static func isSensorMessage(_ number: UInt16) -> Bool {
    number == messageNumber || (0xFF01...0xFF08).contains(number)
  }

  let timestampMicroseconds: UInt64
  let stream: SensorStream
  let validity: SampleValidity
  let channels: [Float]

  init(message: Message) throws {
    guard Self.isSensorMessage(message.globalMessageNumber),
      message.fields.count == SensorField.allCases.count,
      message.fields.allSatisfy({ $0.developerDataIndex == Self.developerIndex && $0.values.count == 1 })
    else { throw AnalysisError(description: "Invalid MTB sample schema") }

    guard case .uint64(let timestamp) = message.firstValue(number: SensorField.timestamp.rawValue),
      case .uint32(let streamID) = message.firstValue(number: SensorField.stream.rawValue),
      case .uint32(let validityID) = message.firstValue(number: SensorField.validity.rawValue)
    else {
      throw SampleDecodingError.invalidFieldType
    }
    timestampMicroseconds = timestamp
    guard let stream = SensorStream(rawValue: streamID),
      let validity = SampleValidity(rawValue: validityID)
    else {
      throw AnalysisError(description: "Unknown sensor stream or validity flag")
    }
    let legacy = message.globalMessageNumber == Self.messageNumber
    guard legacy || message.globalMessageNumber == 0xFF00 + UInt16(stream.rawValue) else {
      throw AnalysisError(description: "Sensor message and stream disagree")
    }
    let channelStart: UInt8 = legacy ? 3 : UInt8(10 + (stream.rawValue - 1) * 6)
    let expectedFields = Set([UInt8(0), 1, 2] + (0..<6).map { channelStart + UInt8($0) })
    guard Set(message.fields.map(\.fieldDefinitionNumber)) == expectedFields else {
      throw AnalysisError(description: "Invalid sensor channel mapping")
    }
    self.stream = stream
    self.validity = validity
    channels = try (0..<6).map { channel in
      guard case .float32(let value) = message.firstValue(number: channelStart + UInt8(channel)) else {
        throw SampleDecodingError.invalidFieldType
      }
      return value
    }
  }
}

private enum SampleDecodingError: Error {
  case invalidFieldType
}
