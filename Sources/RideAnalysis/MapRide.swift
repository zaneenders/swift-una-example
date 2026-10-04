import Foundation

public struct MapPoint: Codable, Sendable {
  public let time: Double
  public let latitude: Double
  public let longitude: Double
}

public struct MapSection: Codable, Sendable {
  public let start: Double
  public let end: Double
  public let paths: [[MapPoint]]
}

public struct MapJump: Codable, Sendable {
  public let start: Double
  public let end: Double
  public let position: MapPoint?
  public let path: [MapPoint]
}

public struct MapRide: Codable, Sendable {
  public let warnings: [String]
  public let route: [[MapPoint]]
  public let lifts: [MapSection]
  public let jumps: [MapJump]
  public let gravityReference: Double
  public let downhillSeconds: Double

  public init(log: SensorLog) throws {
    let locations = log.streams[3] ?? []
    let acceleration = log.streams[1] ?? []
    let clocks = (log.streams[8] ?? []).filter { $0.values.prefix(2).allSatisfy(\.isFinite) }
    guard let anchor = clocks.first else { throw AnalysisError(description: "No valid clock anchor") }
    let offset = anchor.values[0] * 65536 + anchor.values[1] - anchor.time
    let magnitudes = acceleration.map(magnitude).filter { $0.isFinite && $0 > 0 }.sorted()
    guard !magnitudes.isEmpty else { throw AnalysisError(description: "No usable acceleration") }
    gravityReference = magnitudes[magnitudes.count / 2]
    let downhill = classify(locations, ascending: false)
    downhillSeconds = downhill.reduce(0) { $0 + $1.end - $1.start }
    let liftIntervals = classify(locations, ascending: true)
    let jumpIntervals = flights(acceleration, downhill: downhill, gravity: gravityReference, threshold: 0.35)
    func valid(_ point: Point) -> Bool {
      point.values.count >= 2 && point.values[0].isFinite && point.values[1].isFinite
        && abs(point.values[0]) <= 90 && abs(point.values[1]) <= 180
    }
    func mapPoint(_ point: Point) -> MapPoint {
      MapPoint(time: point.time + offset, latitude: point.values[0], longitude: point.values[1])
    }
    var paths: [[MapPoint]] = []
    var path: [MapPoint] = []
    var previous: Point?
    for point in locations {
      if !valid(point) || (previous.map { point.time - $0.time > 3 } ?? false) {
        if !path.isEmpty {
          paths.append(path)
          path = []
        }
      }
      if valid(point) { path.append(mapPoint(point)) }
      previous = point
    }
    if !path.isEmpty { paths.append(path) }
    guard !paths.isEmpty else { throw AnalysisError(description: "No valid GPS route") }
    route = paths
    lifts = liftIntervals.map { interval in
      MapSection(
        start: interval.start + offset, end: interval.end + offset,
        paths: paths.map { $0.filter { $0.time >= interval.start + offset && $0.time <= interval.end + offset } }
          .filter { !$0.isEmpty })
    }
    jumps = jumpIntervals.map { interval in
      let start = interpolateLocation(locations, at: interval.start).map(mapPoint)
      let end = interpolateLocation(locations, at: interval.end).map(mapPoint)
      let center = interpolateLocation(locations, at: (interval.start + interval.end) / 2).map(mapPoint)
      return MapJump(
        start: interval.start + offset, end: interval.end + offset,
        position: center, path: [start, end].compactMap { $0 })
    }
    var notes = log.warnings
    notes.append("Lift and jump candidates are heuristic, not confirmed lift rides or wheel-off-ground time.")
    notes.append(
      "Jump locations interpolate ~1 Hz GPS; wrist acceleration and sensor/uptime clock alignment are unverified.")
    let missingPositions = jumps.filter { $0.position == nil }.count
    if missingPositions > 0 {
      notes.append("\(missingPositions) jump candidates cannot be mapped without bridging missing GPS.")
    }
    warnings = notes
  }
}

public func interpolateLocation(_ points: [Point], at time: Double) -> Point? {
  var low = 0
  var high = points.count
  while low < high {
    let middle = (low + high) / 2
    if points[middle].time < time { low = middle + 1 } else { high = middle }
  }
  func valid(_ point: Point) -> Bool {
    point.values.count >= 2 && point.values.prefix(2).allSatisfy(\.isFinite)
      && abs(point.values[0]) <= 90 && abs(point.values[1]) <= 180
  }
  if low < points.count, points[low].time == time { return valid(points[low]) ? points[low] : nil }
  guard low > 0, low < points.count else { return nil }
  let a = points[low - 1]
  let b = points[low]
  guard valid(a), valid(b), b.time - a.time <= 3, b.time > a.time else { return nil }
  let fraction = (time - a.time) / (b.time - a.time)
  return Point(time: time, values: zip(a.values, b.values).map { $0 + ($1 - $0) * fraction })
}
