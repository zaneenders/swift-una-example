#pragma once
#include <cstdint>

constexpr bool supportsDisplay(int16_t width, int16_t height, uint8_t colorDepth) {
  // UNA reports six color bits; ABGR2222 storage still uses one byte per pixel.
  return width > 0 && height > 0 && width <= 640 && height <= 640 &&
         (colorDepth == 6 || colorDepth == 8);
}
