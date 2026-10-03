#include "SwiftBridge.hpp"

#include <array>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <string>

struct TextCapture {
    std::string text;
    unsigned calls = 0;
};

extern "C" void captureText(void *context, const uint8_t *text, uint32_t length)
{
    auto &capture = *static_cast<TextCapture *>(context);
    capture.text.assign(reinterpret_cast<const char *>(text), length);
    ++capture.calls;
}

int main()
{
    TextCapture capture;
    swift_glance_render_text(&capture, captureText);
    assert(capture.text == "zane was here");
    assert(capture.calls == 1);

    uint32_t tick = 99;
    swift_glance_initialize(&tick);
    const uint32_t *state = &tick;
    assert(swift_glance_tick(state) == 0);
    assert(swift_bird_width() == 48 && swift_bird_height() == 48);
    for (const uint16_t expected : {6, 9, 6, 3}) {
        assert(swift_bird_y(state, 60) == expected);
        swift_glance_advance(&tick);
    }
    assert(swift_glance_tick(state) == 4);
    tick = std::numeric_limits<uint32_t>::max();
    swift_glance_advance(&tick);
    assert(swift_glance_tick(state) == 0);

    std::array<uint8_t, 2305> pixels;
    pixels.fill(0xAA);
    assert(swift_bird_copy(pixels.data(), 2303) == 0);
    for (const auto pixel : pixels) assert(pixel == 0xAA);
    assert(swift_bird_copy(pixels.data(), 2304) == 2304);
    assert(pixels.front() == 0);
    assert(pixels.back() == 0xAA);
    std::puts("Swift C bridge tests passed");
}
