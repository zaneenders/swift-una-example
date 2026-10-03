# MTB Logger

Embedded Swift MTB sensor logger for UNA Watch. Hardware untested.

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

Opening the glance starts a new recording; leaving it or stopping the app
finalizes the FIT file and disconnects sensors. This is **not yet a background
ride app or a jump detector**. Glance lifetime determines recording lifetime.
Hardware support, actual sampling rates and power consumption remain unverified.

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
| Clock anchor | Each glance tick | UTC seconds split into high/low 16-bit halves |

Acceleration and gyro are the primary jump signals. Pressure can provide
vertical context but is affected by airflow; magnetic readings may be distorted
by the bike. GPS is context, not a short-jump detector. Heart rate is not needed
for the initial detector. No filtering, interpolation or jump classification is
applied. The watch cannot directly measure wheel contact; wrist motion can still
cause false positives. Compare recordings against externally noted/video jump
labels when tuning.

`MTB logging` means all seven subscriptions connected, **not** that GPS has a fix
or samples are arriving. `Connecting` means at least one stream is unavailable;
other streams still record. `Log error` indicates storage failure. Reopen to
retry. Do not interact with the watch while riding.

App-relative files: `Rides/ride_<UTC-seconds>_<sequence>.fit`, created without
overwriting existing files. Uses the SDK streaming FIT writer with bounded
per-message memory. Syncs every five glance ticks and finalizes on stop. Abrupt
power loss can leave an unfinalized file; automatic recovery is not implemented.
Expect roughly 20 MB/hour at requested rates. Logs contain private location data;
copy them off regularly and check available storage before riding.

FIT includes standard once-per-glance-tick GPS/speed records, timer events,
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
