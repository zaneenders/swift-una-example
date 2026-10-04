# Ride map

Minimal Hummingbird 2 server using SwiftFit and shared RideAnalysis heuristics. The shape-tree-web app supplied the Hummingbird dependency and application/router reference; it is not modified.

Requires macOS 14+. From the project root:

```sh
swift run -c release RideWeb '/Volumes/UNA WATCH/Apps/SwiftUnaExample/Rides/ride_1791052058_0.fit'
```

Open http://127.0.0.1:8080. Startup decodes the full FIT once (this large ride can take tens of seconds and substantial memory); HTTP requests serve immutable precomputed JSON and HTML. The server binds only to loopback and accepts no uploads or arbitrary file requests. Stop with Control-C.

- Blue: GPS route, split at invalid fixes and gaps over 3 seconds.
- Purple: lift-like ascending sections.
- Orange: all 0.35 g jump candidates, with interpolated short segments and center markers. Click for time and duration, or use the event table's Show buttons.
- Overlay controls toggle each category.

Times use America/Denver. GPS interpolation requires valid bracketing fixes at most 3 seconds apart; positions are approximate, not subsecond GPS measurements. Unmappable candidates stay in the table. Estimates and integrity/clock warnings remain visible. See ../RideAnalyzer/README.md for detector thresholds and limitations.

The FIT is read locally with SwiftFit, never uploaded. Leaflet loads from unpkg and the basemap uses OpenStreetMap tiles: internet access is required, and those services receive normal asset/tile requests. Avoid exposing this unauthenticated personal ride viewer on a public interface.

For the supplied ride: 20,223 GPS fixes, 15 lift sections, and all 35 jump candidates mapped (8.18 s estimated low-force time).
