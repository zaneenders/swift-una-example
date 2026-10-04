import Foundation
import Hummingbird
import RideAnalysis

@main
struct RideWeb {
  static func main() async throws {
    guard #available(macOS 14, *) else {
      throw AnalysisError(description: "RideWeb requires macOS 14 or newer")
    }
    guard CommandLine.arguments.count == 2 else {
      throw AnalysisError(description: "Usage: swift run -c release RideWeb path/to/ride.fit")
    }
    let bytes = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let ride = try MapRide(log: SensorLog(bytes: Array(bytes)))
    let json = String(decoding: try JSONEncoder().encode(ride), as: UTF8.self)
    guard let url = Bundle.module.url(forResource: "index", withExtension: "html") else {
      throw AnalysisError(description: "Missing map page resource")
    }
    let html = try String(contentsOf: url, encoding: .utf8)
    let router = Router()
    router.get("/") { _, _ in
      Response(status: .ok, headers: [.contentType: "text/html; charset=utf-8"], body: .init(byteBuffer: .init(string: html)))
    }
    router.get("/api/ride") { _, _ in
      Response(status: .ok, headers: [.contentType: "application/json"], body: .init(byteBuffer: .init(string: json)))
    }
    let app = Application(router: router, configuration: .init(address: .hostname("127.0.0.1", port: 8080)))
    print("Ride map: http://127.0.0.1:8080 (\(ride.jumps.count) jump candidates, \(ride.lifts.count) lift sections)")
    try await app.runService()
  }
}
