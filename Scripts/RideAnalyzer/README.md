# Lift and jump candidates

Run from the project root:

```sh
swift run -c release RideAnalyzer '/Volumes/UNA WATCH/Apps/SwiftUnaExample/Rides/ride_1791052058_0.fit'
```

The shared RideAnalysis module decodes with SwiftFit, checks the header CRC, validates sensor layouts and increasing timestamps, and checks the file CRC when present. A missing file CRC produces a warning, not an integrity claim. No input files are modified. Analysis requires this app’s developer sensor fields; standard FIT activity records alone are insufficient.

## Lift detection

GPS fixes are divided into disjoint 30-second windows. A lift window requires:

- At least 20 fixes spanning at least 25 seconds, with no gaps over 3 seconds.
- Elevation gain over 10 m and ascent rate over 0.3 m/s.
- Mean GPS-derived speed between 1 and 8 m/s and speed coefficient of variation below 0.35.
- Endpoint distance / total traveled distance above 0.9 (straightness).
- At least 70% of consecutive elevation changes no worse than −1 m.

Adjacent accepted windows join; lift sections must last at least 60 seconds. These are lift-like portions, not a count of complete lift rides: GPS noise, pauses, stations, and transitions can split a ride. Uphill riding could also qualify. Reported totals exclude uncertain windows.

Descending windows use the same coverage checks, descent over 10 m, vertical speed below −0.3 m/s, and horizontal speed above 2 m/s. Jump detection is restricted to these portions; flat jump lines and interruptions in a downhill run are deliberately not inferred.

## Airtime proxy

Use acceleration magnitude `sqrt(x*x + y*y + z*z)`, which is insensitive to watch orientation. A raw accelerometer measures specific force: about 1 g when supported, approaching zero in ballistic free fall. Do **not** subtract gravity before applying this test. The metadata says driver-native units, so the program normalizes by the median valid magnitude rather than assuming a unit conversion. This ride's median is about 9.99, consistent with m/s², but a stationary-watch test is still needed to verify that the driver includes gravity.

A candidate needs continuous magnitude below 0.35 of that reference for 0.12–2 seconds, supported samples on both sides, no gaps over 60 ms, and a landing-like peak over 1.5 g within 300 ms. Invalid data and gaps end the search. Boundary times are midpoints between samples. Outputs at 0.25 and 0.45 g expose threshold sensitivity; they are **not** confidence bounds.

The estimate measures low-force time, not proven tire-off-ground time. Wrist movement, handlebar forces, pumping, and suspension can generate false positives or hide real jumps. The detector needs comparison against video or a bike-mounted sensor before calling the result total airtime. Sensor-stream timestamps are assumed aligned; the app documentation says this needs hardware verification. UTC labels additionally assume sensor time aligns with uptime anchors; anchor drift is reported but does not establish cross-stream alignment.

## Initial result for the supplied ride

- 15 lift-like sections: 3434.65 s (57 min 14.65 s).
- Classified descending portions: 2274.91 s (37 min 54.91 s).
- At 0.35 g: 35 jump candidates, 8.18 s low-force time.
- Sensitivity: 10 candidates / 2.06 s at 0.25 g; 66 / 17.38 s at 0.45 g.
- Complete data section, but missing final file CRC.

These totals are exploratory heuristics, not validated ground truth. The program prints individual candidate timestamps in America/Denver for comparison with video or ride recollection.
