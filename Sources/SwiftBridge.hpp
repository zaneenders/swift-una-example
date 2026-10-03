#pragma once

#include <cstdint>

extern "C" {
// The callback consumes the bytes synchronously; it must not retain the
// pointer.
void swift_glance_render_text(void *context,
                              void (*printText)(void *context,
                                                const uint8_t *text,
                                                uint32_t length));
void swift_glance_initialize(uint32_t *tick);
void swift_glance_advance(uint32_t *tick);
uint32_t swift_glance_tick(const uint32_t *tick);
uint16_t swift_bird_width();
uint16_t swift_bird_height();
uint16_t swift_bird_y(const uint32_t *tick, uint16_t height);
uint32_t swift_bird_copy(uint8_t *destination, uint32_t capacity);
}
