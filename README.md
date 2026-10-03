# SpeederBikes

Embedded Swift MTB sensor logger for UNA Watch. Hardware validation in progress.
The launcher name is **SpeederBikes**; the package filename, app ID and
`Apps/SwiftUnaExample/Rides` storage path remain unchanged for upgrade compatibility.

## Requirements

- macOS 13+ or Linux (Linux build unverified; watch installation is macOS-only)
- [Swiftly](https://www.swift.org/install/) Swift 6.4 with Embedded ARM support
- STM32CubeCLT 1.22.0, CMake, [uv](https://docs.astral.sh/uv/)

## Build / install

```sh
swiftly install 6.4.0
swiftly use 6.4.0
swift run UnaDev doctor
swift run UnaDev build
swift run UnaDev install
```

Or, with the watch connected:

```sh
swift run UnaDev build-install
```

SDK initialization and SDK Python packaging are automatic. Output: `build/SwiftUnaExample_1.0.0.uapp`.

Installation overwrites the existing package. No `sudo`. Eject, disconnect, restart the watch.

## Test

```sh
swift test
```

All tests live under `Tests/`; CLI code lives under `Scripts/` and watch code
under `Sources/`. `Tests/RideDecoderTests/FITRoundTripTests.swift` validates the
C++ writer with SwiftFit. No watch writes. The round-trip test requires `clang++`.

## MTB logger prototype

The app now has a full-screen, physical-button GUI and a separate recording
service. Opening it pre-acquires GPS location/speed but does not create a file or start
recording. The acquired fix is preserved when recording starts. GPS is released
after save or when leaving without recording; missing subscriptions retry each
service tick. **R1 (top right)** starts a ride;
while recording, press R1 twice to stop and confirm saving. **R2 (bottom right)**
cancels a pending save, or closes the GUI. Recording continues with the GUI
closed/suspended; reopen the app to see current state and stop/save. The service
paces recording on its own one-second clock, independent of screen ticks.

The main page shows a larger MM:SS timer (HH:MM:SS after an hour), a GPS
latitude/longitude when GPS has a fresh fix (green), GPS WAIT without a fix
(yellow), and small side-by-side ACC/GYRO health indicators without sample counts. IMU
labels are green while receiving, yellow before first data, red when stale
during recording, muted after save; no LIVE/WAIT text for the IMU. UP/DOWN switches
to a dedicated maximum-speed page (km/h), without affecting recording. The top
status dot is green while recording, amber when ready, white after saving, red
on error. Saved/error states also have explicit text; the app name and recording
heading are omitted. `FIT SAVED` appears only after successful finalization and
file flush/close. Jump detection is offline only; no jump label is displayed.
First validate sensor logs, then tune
against labeled rides. Hardware behavior, button routing, display layout,
background residency and power use remain unverified. The GUI requires an
ABGR2222 display (6-bit color or 8-bit depth, stored as one byte per pixel). There is no touchscreen interface in this prototype.

Requested streams (all samples in each batch are retained):

| Stream | Requested rate | Channels |
|---|---|---|
| Acceleration | 50 Hz | XYZ, documented g; includes gravity |
| Gyroscope | 50 Hz | XYZ, driver units to verify on hardware |
| GPS location | 1 Hz | Latitude/longitude degrees, altitude m, precision m |
| GPS speed | 1 Hz | m/s, validity excludes dead reckoning |
| Pressure | 10 Hz | Pressure Pa, sea-level reference Pa, derived altitude m |
| Magnetic field | 20 Hz | XYZ µT, calibration flag |
| GPS distance | 1 Hz | Cumulative metres |
| Clock anchor | Each service tick | UTC seconds split into high/low 16-bit halves |

Acceleration and gyro are the primary jump signals. Pressure can provide
vertical context but is affected by airflow; magnetic readings may be distorted
by the bike. GPS is context, not a short-jump detector. Heart rate is not needed
for the initial detector. No filtering, interpolation or jump classification is
applied. The watch cannot directly measure wheel contact; wrist motion can still
cause false positives. Compare recordings against externally noted/video jump
labels when tuning.


App-relative files: `Rides/ride_<UTC-seconds>_<sequence>.fit`, created without
overwriting existing files. Uses the SDK streaming FIT writer with bounded
per-message memory. Syncs every five service ticks and finalizes on stop. Abrupt
power loss can leave an unfinalized file; automatic recovery is not implemented.
Expect roughly 20 MB/hour at requested rates. Logs contain private location data;
copy them off regularly and check available storage before riding.

FIT includes standard once-per-second GPS/speed records, timer events,
MTB session and activity summaries. High-rate samples use private message 0xFF00
with developer fields: sensor clock µs, stream ID, validity, six float channels.
IDs 1–8 follow the table order. Unused channels are zero; invalid readings are
retained with validity 0. Clock anchor UTC is `a * 65536 + b`; its timestamp is
system uptime, whereas other timestamps come directly from the sensor layer.
Verify those clocks align on hardware before joining samples. Standard FIT
viewers may ignore private samples; broad activity-import compatibility is not
yet tested. Distance remains in the custom sample stream, not standard totals.

Parse a finalized FIT into typed sensor samples and print basic statistics:

```sh
swift run RideDecoder path/to/ride.fit
```

The CLI uses SwiftFit with header and file CRC validation. It prints counts,
valid/invalid totals, interval min/mean/max, estimated Hz, and duplicate/backward
timestamp counts for all eight streams. Missing streams print `NO SAMPLES`.
`RideData.samples` contains typed `FITSensorSample` values with `SensorStream`,
`SampleValidity`, sensor timestamps and channel values. It reads the whole FIT
into memory, so large recordings may require substantial host RAM. No CSV is
emitted. Older `.mtb` files are not accepted by the CLI. Unfinalized or corrupt
FIT files fail rather than reporting misleading statistics.

Focused tests:

`swift test` includes an end-to-end FIT round-trip test (requires `clang++`):
the actual C++ writer records all eight streams into one file. The legacy streaming
decoder and `SwiftFit` independently decode it. The CLI uses SwiftFit. Tests check timestamps,
validity flags, channel values, developer descriptions, standard GPS records,
MTB session/activity metadata, timer events and CRC rejection.
[`SwiftFit`](https://github.com/zaneenders/swift-fit) is a host-tool GitHub
dependency pinned to a tested revision (Swift 6.3+ required). It is not linked
into the watch app; no sibling checkout is needed.
This validates serialization, not watch sensor delivery.

```sh
swift test
swiftc Sources/RideSample.swift Tests/RideSampleTests.swift -o /tmp/una-ride-tests
/tmp/una-ride-tests
clang++ -std=c++17 -I Sources -I una-sdk/Libs/Header \
  Tests/RideFitWriterTests.cpp Sources/RideFitWriter.cpp \
  una-sdk/Libs/Source/Fit/FitWriter.cpp una-sdk/Libs/Source/Fit/FitCrc.cpp \
  -o /tmp/una-fit-tests
/tmp/una-fit-tests
swift run RideDecoder /tmp/una-ride-test.fit
```

If the system Swift lacks Embedded ARM libraries:

```sh
SWIFTC="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc" swift run UnaDev build
```

Installing replaces our previous bird demo, not Cycling. Start with a short
stationary/walking log to verify sample rates and units before collecting rides.

Button-control test:

```sh
clang++ -std=c++17 -I Sources -I una-sdk/Libs/Header Tests/RideControlsTests.cpp -o /tmp/una-controls-tests
/tmp/una-controls-tests
```

### Self-describing sensor metadata (schema 2)

New FIT recordings contain per-stream developer fields (`accel_x`, `gyro_x`,
`pressure`, `latitude`, etc.) with units and distinct field numbers. Unknown IMU
units are explicitly `driver-native`; no conversion or filtering is applied.
Magnetic fields use documented µT, pressure Pa, GPS degrees/metres and speed m/s.
Clock anchors retain high/low 16-bit UTC-second halves and uptime microseconds.
Private configuration message 0xFF10 stores schema version 2 and eight requested
periods in stream-ID order (zero for the independently paced service tick).
Private sensor messages are 0xFF01–0xFF08; the typed Swift parser also recognizes
older 0xFF00 recordings. The legacy streaming decoder only handles schema 1;
use the SwiftFit-backed CLI for new recordings.

`RideData.channelMetadata` exposes channel names/units and
`requestedPeriodsMilliseconds` exposes requested configuration. The pinned
SwiftFit library decodes these messages without modification. Its convenience
units accessor currently uses field 6, whereas FIT field_description units is
field 8; our parser reads field 8 directly from the decoded message. No changes
to the swift-fit repository are needed. Physical IMU units still require a
stationary/controlled-motion check before detection thresholds are chosen.
