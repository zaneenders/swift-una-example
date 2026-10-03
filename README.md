# Swift UNA Example

A UNA Glance that displays an orange Swift bird beside a counter, both driven by Embedded Swift 6.4. Swift supplies the bird pixels and a gentle vertical bob on each tick. C++ handles UNA messages, owns the backing storage, and submits the controls. Hardware behavior has not been tested.

## Build

Requires the swift.org Swift 6.4 release toolchain with bare-metal Embedded Swift support (Xcode's Swift does not include it), STM32CubeCLT 1.22.0 GNU ARM tools, CMake, and [uv](https://docs.astral.sh/uv/).

Run from the project directory (the host-side tools require Swift 6.2+ and macOS 13+):

```sh
git submodule update --init
swift run UnaDev build
```

Output: `build/SwiftUnaExample_1.0.0.uapp`. `UnaDev` uses swift-subprocess to invoke CMake; CMake still owns Embedded Swift compilation, ARM linking, and SDK packaging. The CLI discovers tools on `PATH`, with fallbacks for `/opt/homebrew/bin`, `~/.cargo/bin`, and STM32CubeCLT 1.22.0's ARM tools. It prefers the installed swift.org Swift 6.4 release compiler; set `SWIFTC` to override it.

```sh
swift run UnaDev doctor        # Check build tools and report watch availability
swift run UnaDev build-install # Build, copy to the watch, and verify
```

SwiftPM downloads host-tool dependencies on the first run. They are not linked into the watch app. Code-only builds need only the `build` command. The build runs the SDK's Python packer through `uv run` with Python 3.10 and the SDK's requirements; no project venv or separate `~/Developer/una-sdk` checkout is needed.

The bird source is checked in. After changing its PNG, regenerate it with `swift run BirdGenerator` before building.

## Install on the watch

Connect the watch with a USB data cable and wait for its drive to appear in Finder:

```sh
swift run UnaDev install
```

This installs the existing build without rebuilding. Use `build-install` to do both. The CLI finds the mounted watch, including numbered paths such as `/Volumes/UNA WATCH 1`, rejects missing or multiple watches, rechecks the mount before copying, and verifies the copied bytes. It does not launch the app or eject the watch.

If no watch is found, reconnect it or try another data cable. To inspect mounted watch paths manually, run `mount | grep '/Volumes/UNA'`. A folder under `/Volumes` is not proof that the watch is mounted.

This overwrites the existing package of the same name. **Do not use `sudo`**, even if you see `Permission denied`. `sudo mkdir` at an unmounted path creates a root-owned folder on your Mac, not on the watch; the subsequent `cp` then fails. Such a folder can also cause the actual watch to mount with a suffix such as `UNA WATCH 1`. Check the mount path again instead of escalating permissions.

Safely eject **UNA WATCH** in Finder, disconnect the cable, and power the watch off and back on. Press the top-right button to find the app/glance.

## Swift bird asset

`Resources/swift-bird.svg` is the source artwork. To regenerate the 48×48 PNG and the SDK-compatible ABGR2222 Swift source (requires Swift 6.2+ and `rsvg-convert`):

```sh
rsvg-convert Resources/swift-bird.svg -o Resources/swift-bird.png
swift run BirdGenerator
```

The generator uses [swift-png](https://github.com/tayloraswift/swift-png) for portable PNG decoding. SwiftPM downloads its dependencies on the first run; they are not linked into the watch app.

## Developer CLI tests

```sh
swift test
```

These cover watch mount discovery, numbered mount paths, unrelated volumes, and ambiguous watches. They do not write to a watch.

## Host tests

```sh
"$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc" \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  Sources/Heartbeat.swift Sources/SwiftBird.swift Tests/GlanceTests.swift \
  -o build/GlanceTests
build/GlanceTests
```

These check counter initialization and wraparound, bird animation bounds, and pixel-buffer capacity handling. They do not validate watch rendering.

The bridge exports use Swift 6.4's `@c(symbol)` attribute, keeping the C symbol names stable. To test the C++ declarations against those exports on the host:

```sh
swiftc="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc"
"$swiftc" -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -parse-as-library -emit-library Sources/Heartbeat.swift Sources/SwiftBird.swift \
  -o build/libSwiftBridge.dylib
clang++ -std=c++17 -ISources Tests/SwiftBridgeTests.cpp \
  -Lbuild -lSwiftBridge -Wl,-rpath,@executable_path -o build/SwiftBridgeTests
build/SwiftBridgeTests
```

Regenerating the bird source now requires Swift 6.4 to compile the resulting `@c` export.

C pointers are converted to `Span`/`MutableSpan` at the Swift boundary; pixel writes use a bounds-checked `MutableSpan` helper without heap allocation. C++ must still provide valid, initialized storage for the duration of each call.

With these span changes, the installed Swift 6.4 release compiler builds the Embedded ARM app but crashes with signal 4 compiling the host tests. Host Swift and C++ bridge tests passed using `swift-DEVELOPMENT-SNAPSHOT-2026-09-10-a` (Swift 6.5-dev); substitute that toolchain in the commands above until the host compiler issue is resolved.
