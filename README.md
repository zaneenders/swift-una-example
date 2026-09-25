# Swift UNA Example

A UNA Glance that displays a counter incremented by Embedded Swift 6.4. C++ handles UNA messages and rendering. Hardware behavior has not been tested.

## Build

Requires the swift.org Swift 6.4 release toolchain with bare-metal Embedded Swift support (Xcode's Swift does not include it), STM32CubeCLT 1.22.0 GNU ARM tools, CMake, and [uv](https://docs.astral.sh/uv/).

```sh
git submodule update --init
export PATH="/opt/ST/STM32CubeCLT_1.22.0/GNU-tools-for-STM32/bin:/opt/homebrew/bin:$PATH"
cmake -S . -B build \
  -DSWIFTC="$HOME/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swiftc"
cmake --build build --parallel 4
```

Output: `build/SwiftUnaExample_1.0.0.uapp`. Subsequent builds need only the last command with the ARM tools on `PATH`. The build runs the SDK's Python packer through `uv run` with Python 3.10 and the SDK's requirements; no project venv or separate `~/Developer/una-sdk` checkout is needed.
