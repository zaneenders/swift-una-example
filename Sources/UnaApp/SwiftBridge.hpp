#pragma once

#include <cstdint>

extern "C" {
void swift_ride_encode(uint8_t *destination, uint64_t timestamp, uint32_t kind,
                       uint32_t valid, float a, float b, float c, float d,
                       float e, float f);
}
