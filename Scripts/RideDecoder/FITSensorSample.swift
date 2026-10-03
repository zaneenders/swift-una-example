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

  let timestampMicroseconds: UInt64
  let stream: SensorStream
  let validity: SampleValidity
  let channels: [Float]

  init(message: Message) throws {
    guard message.globalMessageNumber == Self.messageNumber,
      message.fields.count == SensorField.allCases.count,
      Set(message.fields.map(\.fieldDefinitionNumber)) == Set(SensorField.allCases.map(\.rawValue)),
      message.fields.allSatisfy({ $0.developerDataIndex == Self.developerIndex && $0.values.count == 1 })
    else { throw DecodeError(description: "Invalid MTB sample schema") }

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
      throw DecodeError(description: "Unknown sensor stream or validity flag")
    }
    self.stream = stream
    self.validity = validity
    channels = try SensorField.channels.map { field in
      guard case .float32(let value) = message.firstValue(number: field.rawValue) else {
        throw SampleDecodingError.invalidFieldType
      }
      return value
    }
  }
}

private enum SampleDecodingError: Error {
  case invalidFieldType
}
