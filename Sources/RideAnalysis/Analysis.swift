import Foundation
import SwiftFit

public struct Point: Sendable {
  public init(time: Double, values: [Double]) {
    self.time = time
    self.values = values
  }
  public let time: Double
  public let values: [Double]
}

public struct Interval: Sendable {
  public init(start: Double, end: Double) {
    self.start = start
    self.end = end
  }
  public var start: Double
  public var end: Double
}

public struct AnalysisError: Error, CustomStringConvertible {
  public init(description: String) { self.description = description }
  public let description: String
}

// This reader is deliberately limited to this app's little-endian, uncompressed schema.
// It retains invalid samples as NaNs so missing data cannot bridge a flight interval.
public struct SensorLog {
  public init(streams: [Int: [Point]], warnings: [String]) {
    self.streams = streams
    self.warnings = warnings
  }
  public var streams: [Int: [Point]] = [:]
  public var warnings: [String] = []

  public init(bytes: [UInt8]) throws {
    guard bytes.count >= 14, bytes[0] == 14 else {
      throw AnalysisError(description: "Expected app FIT file")
    }
    let length = (0..<4).reduce(0) { $0 | Int(bytes[4 + $1]) << ($1 * 8) }
    let end = 14 + length
    guard length > 0, end <= bytes.count else {
      throw AnalysisError(description: "Truncated or unfinalized FIT data")
    }
    var input = bytes
    let missingCRC = bytes.count == end
    if missingCRC {
      warnings.append("File CRC is missing; data section is complete but integrity is not verified.")
      // SwiftFit requires two CRC bytes even with validation disabled. This computed
      // placeholder lets it decode complete messages; it does NOT verify the original.
      var crc: UInt16 = 0
      for byte in bytes {
        crc ^= UInt16(byte)
        for _ in 0..<8 { crc = (crc >> 1) ^ (crc & 1 == 1 ? 0xA001 : 0) }
      }
      input.append(UInt8(truncatingIfNeeded: crc))
      input.append(UInt8(truncatingIfNeeded: crc >> 8))
    } else if bytes.count != end + 2 {
      throw AnalysisError(description: "Unexpected trailing FIT data")
    }
    let fit = try FITFile(
      bytes: input,
      options: FITDecodeOptions(validateFileCRC: !missingCRC, validateHeaderCRC: true))
    for message in fit.messages where FITSensorSample.isSensorMessage(message.globalMessageNumber) {
      let sample = try FITSensorSample(message: message)
      let values =
        sample.validity == .valid
        ? sample.channels.map(Double.init) : Array(repeating: Double.nan, count: 6)
      streams[Int(sample.stream.rawValue), default: []].append(
        Point(time: Double(sample.timestampMicroseconds) / 1e6, values: values))
    }
    for points in streams.values {
      guard zip(points, points.dropFirst()).allSatisfy({ $0.time < $1.time }) else {
        throw AnalysisError(description: "Duplicate/backward sensor timestamps; cannot safely estimate durations")
      }
    }
  }
}

public func distance(_ a: Point, _ b: Point) -> Double {
  let radians = Double.pi / 180
  let latitude = (a.values[0] + b.values[0]) / 2 * radians
  return hypot(
    (b.values[0] - a.values[0]) * radians,
    (b.values[1] - a.values[1]) * radians * cos(latitude)) * 6_371_000
}

public func classify(_ points: [Point], ascending: Bool) -> [Interval] {
  var windows: [Interval] = []
  // Disjoint 30-second windows intentionally leave uncertain transitions unclassified.
  var index = 0
  while index < points.count {
    let start = index
    while index < points.count && points[index].time - points[start].time < 30 { index += 1 }
    let window = Array(points[start..<index])
    guard window.count >= 20, let first = window.first, let last = window.last,
      last.time - first.time >= 25,
      window.allSatisfy({
        $0.values.prefix(3).allSatisfy(\.isFinite) && abs($0.values[0]) <= 90 && abs($0.values[1]) <= 180
      }),
      zip(window, window.dropFirst()).allSatisfy({ $1.time - $0.time <= 3 })
    else { continue }
    let pairs = Array(zip(window, window.dropFirst()))
    let speeds = pairs.map { distance($0, $1) / ($1.time - $0.time) }
    let mean = speeds.reduce(0, +) / Double(speeds.count)
    let deviation = sqrt(speeds.reduce(0) { $0 + pow($1 - mean, 2) } / Double(speeds.count))
    let path = pairs.reduce(0) { $0 + distance($1.0, $1.1) }
    let gain = last.values[2] - first.values[2]
    let slope = gain / (last.time - first.time)
    let risingFraction = Double(pairs.filter { $1.values[2] >= $0.values[2] - 1 }.count) / Double(pairs.count)
    let accepted =
      ascending
      ? slope > 0.3 && gain > 10 && mean > 1 && mean < 8 && deviation / mean < 0.35
        && distance(first, last) / max(path, 1) > 0.9 && risingFraction > 0.7
      : slope < -0.3 && gain < -10 && mean > 2
    if accepted {
      if let previous = windows.last, first.time - previous.end <= 3 {
        windows[windows.count - 1].end = last.time
      } else {
        windows.append(Interval(start: first.time, end: last.time))
      }
    }
  }
  return ascending ? windows.filter { $0.end - $0.start >= 60 } : windows
}

public func magnitude(_ point: Point) -> Double {
  sqrt(point.values.prefix(3).reduce(0) { $0 + $1 * $1 })
}

public func flights(_ points: [Point], downhill: [Interval], gravity: Double, threshold: Double) -> [Interval] {
  var result: [Interval] = []
  var start: Int?
  for index in points.indices {
    let low = magnitude(points[index]) < gravity * threshold
    let continuous = index > 0 && points[index].time - points[index - 1].time <= 0.06
    if low && (start == nil || continuous) {
      if start == nil { start = index }
      continue
    }
    if let beginning = start {
      let end = index - 1
      let duration = points[end].time - points[beginning].time
      // Require observed support on both sides; never count gaps or unfinished events.
      if beginning > 0, continuous, !low, duration >= 0.12, duration <= 2,
        points[beginning].time - points[beginning - 1].time <= 0.06,
        magnitude(points[beginning - 1]).isFinite,
        magnitude(points[index]).isFinite,
        downhill.contains(where: { points[beginning].time >= $0.start && points[index].time <= $0.end })
      {
        let landingEnd = points[index].time + 0.3
        var landingPeak = 0.0
        var next = index
        while next < points.count && points[next].time <= landingEnd {
          if next > index && points[next].time - points[next - 1].time > 0.06 { break }
          let force = magnitude(points[next])
          if !force.isFinite { break }
          landingPeak = max(landingPeak, force)
          next += 1
        }
        if landingPeak > gravity * 1.5 {
          result.append(
            Interval(
              start: (points[beginning - 1].time + points[beginning].time) / 2,
              end: (points[end].time + points[index].time) / 2))
        }
      }
    }
    start = low ? index : nil
  }
  return result
}
