import RideAnalysis
import Foundation

@main
struct RideAnalyzer {
  static func main() {
    do {
      guard CommandLine.arguments.count == 2 else {
        throw AnalysisError(description: "Usage: swift run -c release RideAnalyzer ride.fit")
      }
      let log = try SensorLog(bytes: Array(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))))
      for warning in log.warnings { print("WARNING: \(warning)") }
      let locations = log.streams[3] ?? []
      let acceleration = log.streams[1] ?? []
      let clocks = (log.streams[8] ?? []).filter { $0.values.prefix(2).allSatisfy(\.isFinite) }
      guard let anchor = clocks.first else { throw AnalysisError(description: "No valid UTC anchor") }
      let offset = anchor.values[0] * 65536 + anchor.values[1] - anchor.time
      let residuals = clocks.map { $0.values[0] * 65536 + $0.values[1] - $0.time - offset }
      print(String(format: "Clock anchor drift range: %.2f to %.2f seconds", residuals.min() ?? 0, residuals.max() ?? 0))
      let formatter = DateFormatter()
      formatter.timeZone = TimeZone(identifier: "America/Denver")
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS z"
      func timestamp(_ time: Double) -> String { formatter.string(from: Date(timeIntervalSince1970: time + offset)) }
      func report(_ name: String, _ intervals: [Interval]) {
        let total = intervals.reduce(0) { $0 + $1.end - $1.start }
        print(String(format: "%@: %d candidates, %.2f seconds", name, intervals.count, total))
        for interval in intervals {
          print(String(format: "  %@ → %@ (%.2f s)", timestamp(interval.start), timestamp(interval.end), interval.end - interval.start))
        }
      }
      let lifts = classify(locations, ascending: true)
      let downhill = classify(locations, ascending: false)
      report("Lift", lifts)
      report("Downhill (classified portions only)", downhill)
      let magnitudes = acceleration.map(magnitude).filter { $0.isFinite && $0 > 0 }.sorted()
      guard !magnitudes.isEmpty else { throw AnalysisError(description: "No usable acceleration") }
      let gravity = magnitudes[magnitudes.count / 2]
      print(String(format: "Empirical 1 g reference (median magnitude, driver-native units): %.4f", gravity))
      print("Assumes raw specific-force acceleration including gravity; verify with a stationary watch test.")
      print("Sensor timestamps are assumed aligned across streams; UTC labels assume alignment with uptime anchors.")
      for threshold in [0.25, 0.35, 0.45] {
        let candidates = flights(acceleration, downhill: downhill, gravity: gravity, threshold: threshold)
        if threshold == 0.35 { report("Jump low-force airtime estimate (0.35 g)", candidates) }
        else {
          print(String(format: "Sensitivity at %.2f g: %d candidates, %.2f seconds", threshold,
            candidates.count, candidates.reduce(0) { $0 + $1.end - $1.start }))
        }
      }
      print("Not confirmed wheel-off-ground time: wrist motion can create false positives or hide flight. Unclassified terrain and sensor gaps are excluded.")
    } catch {
      try? FileHandle.standardError.write(contentsOf: Data("\(error)\n".utf8))
      exit(1)
    }
  }
}
