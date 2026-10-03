# Swift UNA Example

Embedded Swift UNA Glance. Hardware untested.

## Requirements

- macOS 13+, host Swift 6.2+
- [swift.org Swift 6.4](https://www.swift.org/install/) with Embedded ARM support (not Xcode's Swift)
- STM32CubeCLT 1.22.0, CMake, [uv](https://docs.astral.sh/uv/), `rsvg-convert` (`brew install librsvg`)

## Build / install

```sh
swift run UnaDev doctor
swift run UnaDev build
swift run UnaDev install
```

Or, with the watch connected:

```sh
swift run UnaDev build-install
```

SDK initialization, bird generation, and Python packaging are automatic. Output: `build/SwiftUnaExample_1.0.0.uapp`.

Installation overwrites the existing package. No `sudo`. Eject, disconnect, restart the watch.

## Test

```sh
swift test
```

CLI tests only; no watch writes. Swift 6.4 crashes compiling the separate host glance/bridge tests; those require a compatible development toolchain.
