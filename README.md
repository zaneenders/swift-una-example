# SpeederBikes

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

## Web View 

```sh
swift run -c release RideWeb '/Volumes/UNA WATCH/Apps/SwiftUnaExample/Rides/ride_1791052058_0.fit'
```

