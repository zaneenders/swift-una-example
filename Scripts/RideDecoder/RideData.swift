import Foundation
import SwiftFit

struct RideData {
  let samples: [FITSensorSample]
  let schemaVersion: UInt16
  let requestedPeriodsMilliseconds: [UInt32]
  let channelMetadata: [DeveloperFieldKey: (name: String, units: String)]

  init(bytes: Data) throws {
    let options = FITDecodeOptions(validateFileCRC: true, validateHeaderCRC: true)
    let fit = try FITFile(bytes: Array(bytes), options: options)
    let configuration = fit.messages.first { $0.globalMessageNumber == 0xFF10 }
    schemaVersion = configuration?.uint16Field(number: 0) ?? 1
    guard schemaVersion == 1 || schemaVersion == 2 else {
      throw DecodeError(description: "Unsupported ride schema version")
    }
    requestedPeriodsMilliseconds =
      configuration?.field(number: 1)?.values.compactMap {
        if case .uint32(let period) = $0 { return period }
        return nil
      } ?? []
    if schemaVersion == 2 && requestedPeriodsMilliseconds.count != 8 {
      throw DecodeError(description: "Invalid sensor configuration")
    }
    // FIT field_description units is field 8; the pinned SwiftFit convenience map uses 6.
    var metadata: [DeveloperFieldKey: (name: String, units: String)] = [:]
    for message in fit.messages where message.globalMessageNumber == 206 {
      if let index = message.uint8Field(number: 0), let field = message.uint8Field(number: 1),
        let name = message.stringField(number: 3)
      {
        metadata[DeveloperFieldKey(developerDataIndex: index, fieldDefinitionNumber: field)] =
          (name, message.stringField(number: 8) ?? "")
      }
    }
    channelMetadata = metadata
    samples = try fit.messages
      .filter { FITSensorSample.isSensorMessage($0.globalMessageNumber) }
      .map { try FITSensorSample(message: $0) }
    guard !samples.isEmpty else {
      throw DecodeError(description: "FIT file contains no MTB sensor samples")
    }
  }

  func statistics(for stream: SensorStream) -> StreamStatistics {
    var statistics = StreamStatistics()
    for sample in samples where sample.stream == stream {
      statistics.add(sample)
    }
    return statistics
  }

  var summary: String {
    var lines = ["Parsed \(samples.count) sensor samples (FIT CRCs verified)."]
    for stream in SensorStream.allCases {
      let stats = statistics(for: stream)
      guard stats.count > 0 else {
        lines.append("\(stream.name): NO SAMPLES")
        continue
      }
      lines.append(
        "\(stream.name): \(stats.count) samples; \(stats.validCount) valid, \(stats.count - stats.validCount) invalid")
      if let minimum = stats.timing.minimumInterval {
        let meanMilliseconds = stats.timing.meanInterval / 1000
        let rate = 1_000_000 / stats.timing.meanInterval
        lines.append(
          String(
            format: "  interval ms min/mean/max: %.3f / %.3f / %.3f; estimated %.1f Hz",
            Double(minimum) / 1000, meanMilliseconds,
            Double(stats.timing.maximumInterval) / 1000, rate))
      } else {
        lines.append("  insufficient increasing timestamps to estimate rate")
      }
      lines.append(
        "  duplicate timestamps: \(stats.duplicateTimestamps); backward timestamps: \(stats.backwardTimestamps)")
    }
    return lines.joined(separator: "\n")
  }
}

struct StreamStatistics {
  private(set) var count = 0
  private(set) var validCount = 0
  private(set) var duplicateTimestamps = 0
  private(set) var backwardTimestamps = 0
  private(set) var timing = SensorSummary()

  mutating func add(_ sample: FITSensorSample) {
    count += 1
    if sample.validity == .valid { validCount += 1 }
    if let previous = timing.previous {
      if sample.timestampMicroseconds == previous { duplicateTimestamps += 1 }
      if sample.timestampMicroseconds < previous { backwardTimestamps += 1 }
    }
    timing.add(sample.timestampMicroseconds)
  }
}

@main
struct RideDecoder {
  static func main() {
    do {
      guard CommandLine.arguments.count == 2 else {
        throw DecodeError(description: "Usage: swift run RideDecoder path/to/ride.fit")
      }
      let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
      let ride = try RideData(bytes: bytes)
      print(ride.summary)
    } catch {
      try? FileHandle.standardError.write(contentsOf: Data("\(error)\n".utf8))
      exit(1)
    }
  }
}
