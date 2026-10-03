import Foundation
import SwiftFit

struct RideData {
  let samples: [FITSensorSample]

  init(bytes: Data) throws {
    let options = FITDecodeOptions(validateFileCRC: true, validateHeaderCRC: true)
    let fit = try FITFile(bytes: Array(bytes), options: options)
    samples = try fit.messages
      .filter { $0.globalMessageNumber == FITSensorSample.messageNumber }
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
