# Swift UNA Example

A UNA Glance that displays an orange Swift bird beside a counter, both driven by Embedded Swift 6.4. Swift supplies the bird pixels and a gentle vertical bob on each tick. C++ handles UNA messages, owns the backing storage, and submits the controls. Hardware behavior has not been tested.

## Build

Requires the swift.org Swift 6.4 release toolchain with bare-metal Embedded Swift support (Xcode's Swift does not include it), STM32CubeCLT 1.22.0 GNU ARM tools, CMake, and [uv](https://docs.astral.sh/uv/).

Run from the project directory:

```sh
export PATH="/opt/ST/STM32CubeCLT_1.22.0/GNU-tools-for-STM32/bin:/opt/homebrew/bin:$HOME/.cargo/bin:$PATH"
git submodule update --init
swift run --package-path Scripts BirdGenerator
cmake -S . -B build \
  -DSWIFTC="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc"
cmake --build build --parallel 4
```

Output: `build/SwiftUnaExample_1.0.0.uapp`. The generator refreshes `Sources/SwiftBird.swift` from the existing PNG using swift-png; SwiftPM downloads its dependencies on the first run. Subsequent code-only builds need only the last command with the ARM tools and `uv` on `PATH`. The build runs the SDK's Python packer through `uv run` with Python 3.10 and the SDK's requirements; no project venv or separate `~/Developer/una-sdk` checkout is needed.

## Install on the watch

Connect the watch with a USB data cable and wait for its drive to appear in Finder. From the project directory, run the following block. It automatically finds the mounted watch, including numbered paths such as `/Volumes/UNA WATCH 1`, rather than relying on a hardcoded name.

```sh
(
  set -eu
  package="build/SwiftUnaExample_1.0.0.uapp"
  watch_volume=$(mount | awk '
    / on \/Volumes\/UNA WATCH( [0-9]+)? \(/ {
      sub(/^.* on /, "")
      sub(/ \(.*/, "")
      print
    }')

  case "$watch_volume" in
    "") printf 'No mounted UNA watch found; nothing copied.\n' >&2; exit 1 ;;
    *'
'*) printf 'Multiple watches found; nothing copied.\n' >&2; exit 1 ;;
  esac
  test -f "$package" || { printf 'Build the app first; package is missing.\n' >&2; exit 1; }
  mount | grep -Fq " on $watch_volume (" || { printf 'Watch disconnected; nothing copied.\n' >&2; exit 1; }

  destination="$watch_volume/Apps/SwiftUnaExample"
  mkdir -p "$destination"
  cp "$package" "$destination/"
  cmp "$package" "$destination/SwiftUnaExample_1.0.0.uapp"
  printf 'Copied and verified app at %s\n' "$destination"
)
```

If no watch is found, reconnect it or try another data cable. To inspect mounted watch paths manually, run `mount | grep '/Volumes/UNA'`. A folder under `/Volumes` is not proof that the watch is mounted.

This overwrites the existing package of the same name. **Do not use `sudo`**, even if you see `Permission denied`. `sudo mkdir` at an unmounted path creates a root-owned folder on your Mac, not on the watch; the subsequent `cp` then fails. Such a folder can also cause the actual watch to mount with a suffix such as `UNA WATCH 1`. Check the mount path again instead of escalating permissions.

Safely eject **UNA WATCH** in Finder, disconnect the cable, and power the watch off and back on. Press the top-right button to find the app/glance.

## Swift bird asset

`Resources/swift-bird.svg` is the source artwork. To regenerate the 48×48 PNG and the SDK-compatible ABGR2222 Swift source (requires Swift 5.10+ and `rsvg-convert`):

```sh
rsvg-convert Resources/swift-bird.svg -o Resources/swift-bird.png
swift run --package-path Scripts BirdGenerator
```

The generator uses [swift-png](https://github.com/tayloraswift/swift-png) for portable PNG decoding. SwiftPM downloads its dependencies on the first run; they are not linked into the watch app.

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
