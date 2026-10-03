#include "Gui.hpp"
#include "SDK/Messages/CommandMessages.hpp"
#include "SDK/Messages/MessageGuard.hpp"
#include <algorithm>
#include <cstdio>
#include <cstring>

// Five-column bitmap font keeps this prototype independent of a GUI toolkit.
namespace {
const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789:- /.";
const uint8_t glyphs[][5] = {
 {126,9,9,9,126},{127,73,73,73,54},{62,65,65,65,34},{127,65,65,34,28},
 {127,73,73,73,65},{127,9,9,9,1},{62,65,73,73,122},{127,8,8,8,127},
 {0,65,127,65,0},{32,64,65,63,1},{127,8,20,34,65},{127,64,64,64,64},
 {127,2,12,2,127},{127,4,8,16,127},{62,65,65,65,62},{127,9,9,9,6},
 {62,65,81,33,94},{127,9,25,41,70},{70,73,73,73,49},{1,1,127,1,1},
 {63,64,64,64,63},{31,32,64,32,31},{63,64,56,64,63},{99,20,8,20,99},
 {7,8,112,8,7},{97,81,73,69,67},{62,81,73,69,62},{0,66,127,64,0},
 {98,81,73,73,70},{34,65,73,73,54},{24,20,18,127,16},{39,69,69,69,57},
 {60,74,73,73,48},{1,113,9,5,3},{54,73,73,73,54},{6,73,73,41,30},
 {0,54,54,0,0},{8,8,8,8,8},{0,0,0,0,0},{96,16,8,4,3},{0,96,96,0,0}
};
}

void Gui::text(int x, int y, const char *label, uint8_t color) {
  const int scale = width >= 200 ? 2 : 1;
  for (; *label; ++label, x += 6 * scale) {
    const char *found = std::strchr(alphabet, *label);
    if (!found) continue;
    const auto &glyph = glyphs[found - alphabet];
    for (int column = 0; column < 5; ++column)
      for (int row = 0; row < 7; ++row)
        if (glyph[column] & (1 << row))
          for (int dx = 0; dx < scale; ++dx)
            for (int dy = 0; dy < scale; ++dy) {
              const int px = x + column * scale + dx, py = y + row * scale + dy;
              if (px >= 0 && py >= 0 && px < width && py < height)
                pixels[py * width + px] = color;
            }
  }
}

void Gui::draw() {
  if (!visible || pixels.empty()) return;
  std::fill(pixels.begin(), pixels.end(), 0xC0);
  const int x = width / 8, top = height / 8, step = height / 11;
  char line[48];
  text(x, top, "MTB LOGGER");
  const char *phase = state.phase == RideMessage::Phase::Recording ? "RECORDING" :
                      state.phase == RideMessage::Phase::Saved ? "FIT SAVED" :
                      state.phase == RideMessage::Phase::Error ? "SAVE/LOG ERROR" : "READY";
  text(x, top + step, phase);
  std::snprintf(line,sizeof(line),"TIME %02lu:%02lu:%02lu",
    static_cast<unsigned long>(state.elapsedSeconds / 3600),
    static_cast<unsigned long>(state.elapsedSeconds / 60 % 60),
    static_cast<unsigned long>(state.elapsedSeconds % 60));
  text(x, top + step * 2, line);
  text(x, top + step * 3, state.gpsFix ? "GPS FIX" : "GPS NO FIX");
  std::snprintf(line,sizeof(line),"ACC %lu %s",static_cast<unsigned long>(state.accelerationCount),state.accelerationLive ? "LIVE" : "WAIT");
  text(x, top + step * 4, line);
  std::snprintf(line,sizeof(line),"GYRO %lu %s",static_cast<unsigned long>(state.gyroCount),state.gyroLive ? "LIVE" : "WAIT");
  text(x, top + step * 5, line);
  if (state.maxSpeedAvailable)
    std::snprintf(line, sizeof(line), "MAX %.1f KM/H", static_cast<double>(state.maxSpeedKmh));
  else std::snprintf(line, sizeof(line), "MAX -- KM/H");
  text(x, top + step * 6, line);
  text(x, top + step * 7, "JUMPS NOT ENABLED");
  text(x, top + step * 8, controls.confirmingSave() ? "R1 CONFIRM SAVE" :
       state.phase == RideMessage::Phase::Recording ? "R1 STOP AND SAVE" : "R1 START RIDE");
  text(x, top + step * 9, controls.confirmingSave() ? "R2 CANCEL" : "R2 BACK");
  if (auto update = SDK::make_msg<SDK::Message::RequestDisplayUpdate>(kernel)) {
    update->pBuffer = pixels.data();
    update.send(100);
  }
}

void Gui::run() {
  if (auto config = SDK::make_msg<SDK::Message::RequestDisplayConfig>(kernel)) {
    if (!config.send(100) || !config.ok() || config->width <= 0 ||
        config->height <= 0 || config->width > 640 || config->height > 640 || config->colorDepth != 8) return;
    width = config->width; height = config->height;
    pixels.resize(static_cast<size_t>(width) * height);
  } else return;
  SDK::send_msg<RideMessage::Request>(kernel);
  while (true) {
    SDK::MessageBase *message = nullptr;
    if (!kernel.comm.getMessage(message, 1000)) continue;
    switch (message->getType()) {
    case SDK::MessageType::COMMAND_APP_STOP:
      kernel.comm.releaseMessage(message);
      return;
    case SDK::MessageType::COMMAND_APP_GUI_RESUME:
      visible = true;
      controls.cancel();
      SDK::send_msg<RideMessage::Request>(kernel);
      break;
    case SDK::MessageType::COMMAND_APP_GUI_SUSPEND:
      visible = false;
      controls.cancel();
      break;
    case RideMessage::status:
      state = static_cast<RideMessage::Status *>(message)->state;
      break;
    case SDK::MessageType::EVENT_BUTTON: {
      auto &button = *static_cast<SDK::Message::EventButton *>(message);
      if (!visible || button.event != SDK::Message::EventButton::Event::CLICK) break;
      if (button.id == SDK::Message::EventButton::Id::SW2) {
        switch (controls.select(state.phase)) {
        case RideControls::Action::Start: SDK::send_msg<RideMessage::Start>(kernel); break;
        case RideControls::Action::Save: SDK::send_msg<RideMessage::Stop>(kernel); break;
        case RideControls::Action::None: break;
        }
      } else if (button.id == SDK::Message::EventButton::Id::SW4) {
        if (controls.confirmingSave()) controls.cancel();
        else { kernel.comm.releaseMessage(message); return; }
      }
      break;
    }
    default: break;
    }
    kernel.comm.releaseMessage(message);
    draw();
  }
}
