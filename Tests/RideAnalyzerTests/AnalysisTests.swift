import RideAnalysis
import Testing

private func acceleration(_ index: Int, _ value: Double) -> Point {
  Point(time: Double(index) * 0.02, values: [0, 0, value])
}

@Test func freeFallWithLanding() {
  let points = (0..<100).map { acceleration($0, (20..<40).contains($0) ? 0.1 : ($0 == 40 ? 2 : 1)) }
  let result = flights(points, downhill: [Interval(start: 0, end: 2)], gravity: 1, threshold: 0.35)
  #expect(result.count == 1)
  #expect(abs((result[0].end - result[0].start) - 0.4) < 0.0001)
  #expect(flights(points, downhill: [], gravity: 1, threshold: 0.35).isEmpty)
}

@Test func noImpactAndInvalidDataRejected() {
  let points = (0..<100).map { acceleration($0, (20..<40).contains($0) ? 0.1 : 1) }
  #expect(flights(points, downhill: [Interval(start: 0, end: 2)], gravity: 1, threshold: 0.35).isEmpty)
  var invalid = points
  invalid[30] = acceleration(30, .nan)
  invalid[40] = acceleration(40, 2)
  #expect(flights(invalid, downhill: [Interval(start: 0, end: 2)], gravity: 1, threshold: 0.35).isEmpty)
}

@Test func gapDoesNotBecomeAirtime() {
  var points = (0..<100).map { acceleration($0, (20..<40).contains($0) ? 0.1 : ($0 == 40 ? 2 : 1)) }
  points.removeSubrange(21..<39)
  #expect(flights(points, downhill: [Interval(start: 0, end: 2)], gravity: 1, threshold: 0.35).isEmpty)
}

@Test func steadyStraightAscentVersusDescent() {
  func track(_ slope: Double) -> [Point] {
    (0..<120).map { Point(time: Double($0), values: [40 + Double($0) * 0.00003, -111, 2000 + Double($0) * slope]) }
  }
  #expect(classify(track(1), ascending: true).count == 1)
  #expect(classify(track(-1), ascending: true).isEmpty)
  #expect(classify(track(-1), ascending: false).count == 1)
  #expect(classify(track(0), ascending: true).isEmpty)
  var invalid = track(1)
  for i in stride(from: 0, to: 120, by: 20) { invalid[i] = Point(time: Double(i), values: [.nan, .nan, .nan]) }
  #expect(classify(invalid, ascending: true).isEmpty)
}

@Test func rejectsMalformedFile() {
  #expect(throws: AnalysisError.self) { try SensorLog(bytes: []) }
}

@Test func mapInterpolationDoesNotBridgeGapsOrInvalidFixes() {
  let points = [Point(time: 0, values: [40, -111, 2000]), Point(time: 1, values: [40.001, -111, 2001])]
  let middle = interpolateLocation(points, at: 0.5)
  #expect(middle != nil)
  #expect(abs(middle!.values[0] - 40.0005) < 0.000001)
  #expect(interpolateLocation(points, at: -1) == nil)
  #expect(interpolateLocation(points, at: 2) == nil)
  #expect(interpolateLocation([points[0], Point(time: 4, values: points[1].values)], at: 2) == nil)
  #expect(interpolateLocation([points[0], Point(time: 1, values: [.nan, -111])], at: 0.5) == nil)
}

@Test func mapSummaryPreservesCandidateCountsAndClockOffset() throws {
  let locations = (0..<120).map {
    Point(time: Double($0), values: [40 + Double($0) * 0.00003, -111, 2000 - Double($0)])
  }
  let acceleration = (0..<6000).map {
    Point(time: Double($0) * 0.02, values: [0, 0, (1000..<1020).contains($0) ? 0.1 : ($0 == 1020 ? 2 : 1)])
  }
  let log = SensorLog(
    streams: [
      1: acceleration, 3: locations,
      8: [Point(time: 0, values: [0, 1000])],
    ], warnings: ["test warning"])
  let ride = try MapRide(log: log)
  #expect(ride.jumps.count == 1)
  #expect(ride.jumps[0].position != nil)
  #expect(ride.jumps[0].start > 1019)
  #expect(ride.route[0][0].time == 1000)
  #expect(ride.warnings.contains("test warning"))
}
