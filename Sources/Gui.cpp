#include "Gui.hpp"
#include "DisplayConfiguration.hpp"
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

void Gui::text(int x, int y, const char *label, uint8_t color, int scale) {
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

void Gui::centered(int y, const char *label, uint8_t color, int scale) {
  centeredAt(width / 2, y, width * 3 / 4, label, color, scale);
}

void Gui::centeredAt(int centerX, int y, int availableWidth, const char *label, uint8_t color, int scale) {
  const int length = static_cast<int>(std::strlen(label));
  while (scale > 1 && length * 6 * scale > availableWidth) --scale;
  const int textWidth = length ? (length * 6 - 1) * scale : 0;
  text(centerX - textWidth / 2, y, label, color, scale);
}

void Gui::draw() {
  if (!visible || pixels.empty()) return;
  constexpr uint8_t white = 0xFF, muted = 0xEA, green = 0xCC, amber = 0xCB, red = 0xC3;
  std::fill(pixels.begin(), pixels.end(), 0xC0);
  const auto y = [this](int position) { return height * position / 240; };
  const bool recording = state.phase == RideMessage::Phase::Recording;
  const bool saved = state.phase == RideMessage::Phase::Saved;
  const bool failed = state.phase == RideMessage::Phase::Error;
  char line[48];
  // Status dot: green recording, amber ready, white saved, red error.
  const auto statusColor = failed ? red : recording ? green : saved ? white : amber;
  const int radius = 4, dotY = y(25), dotX = width / 2;
  for (int dy = -radius; dy <= radius; ++dy)
    for (int dx = -radius; dx <= radius; ++dx)
      if (dx*dx + dy*dy <= radius*radius && dotX+dx >= 0 && dotX+dx < width &&
          dotY+dy >= 0 && dotY+dy < height)
        pixels[(dotY+dy)*width+dotX+dx] = statusColor;
  if (saved || failed) centered(y(39), saved ? "FIT SAVED" : "LOG ERROR", failed ? red : white, 1);

  if (controls.page() == RideControls::Page::Ride) {
    if (state.elapsedSeconds < 3600) {
      std::snprintf(line, sizeof(line), "%02lu:%02lu",
        static_cast<unsigned long>(state.elapsedSeconds / 60),
        static_cast<unsigned long>(state.elapsedSeconds % 60));
    } else {
      std::snprintf(line, sizeof(line), "%02lu:%02lu:%02lu",
        static_cast<unsigned long>(state.elapsedSeconds / 3600),
        static_cast<unsigned long>(state.elapsedSeconds / 60 % 60),
        static_cast<unsigned long>(state.elapsedSeconds % 60));
    }
    centered(y(60), line, white, 5);

    if (state.gpsFix) {
      std::snprintf(line, sizeof(line), "LAT %.5f", static_cast<double>(state.latitude));
      centered(y(103), line, green, 2);
      std::snprintf(line, sizeof(line), "LON %.5f", static_cast<double>(state.longitude));
      centered(y(122), line, green, 2);
    } else {
      centered(y(111), saved ? "GPS OFF" : "GPS WAIT", saved ? muted : amber, 2);
    }
    const auto sensorColor = [&](bool live, uint32_t received) {
      return saved ? muted : live ? green : recording && received > 0 ? red : amber;
    };
    if (state.accelerationLive)
      std::snprintf(line, sizeof(line), "A:%.1f", static_cast<double>(state.accelerationMagnitude));
    else std::snprintf(line, sizeof(line), "A:--");
    centeredAt(width / 3, y(160), width / 3, line,
               sensorColor(state.accelerationLive, state.accelerationCount), 2);
    if (state.gyroLive)
      std::snprintf(line, sizeof(line), "G:%.1f", static_cast<double>(state.gyroMagnitude));
    else std::snprintf(line, sizeof(line), "G:--");
    centeredAt(width * 2 / 3, y(160), width / 3, line,
               sensorColor(state.gyroLive, state.gyroCount), 2);
  } else {
    centered(y(65), "MAX SPEED", muted, 2);
    if (state.maxSpeedAvailable)
      std::snprintf(line, sizeof(line), "%.1f", static_cast<double>(state.maxSpeedKmh));
    else std::snprintf(line, sizeof(line), "--");
    centered(y(100), line, white, 5);
    centered(y(148), "KM/H", muted, 2);
  }


  centered(y(201), controls.confirmingSave() ? "R1 SAVE" : recording ? "R1 STOP" : "R1 START",
           controls.confirmingSave() ? amber : green);
  centered(y(218), controls.confirmingSave() ? "R2 CANCEL" : "R2 BACK", muted, 1);
  if (auto update = SDK::make_msg<SDK::Message::RequestDisplayUpdate>(kernel)) {
    update->pBuffer = pixels.data();
    update.send(100);
  }
}

void Gui::run() {
  if (auto config = SDK::make_msg<SDK::Message::RequestDisplayConfig>(kernel)) {
    if (!config.send(100) || !config.ok() ||
        !supportsDisplay(config->width, config->height, config->colorDepth)) return;
    width = config->width; height = config->height;
    pixels.resize(static_cast<size_t>(width) * height);
  } else return;
  SDK::send_msg<RideMessage::Request>(kernel);
  while (true) {
    SDK::MessageBase *message = nullptr;
    if (!kernel.comm.getMessage(message, 1000)) continue;
    switch (message->getType()) {
    case SDK::MessageType::COMMAND_APP_STOP:
      message->setResult(SDK::MessageResult::SUCCESS);
      kernel.comm.releaseMessage(message);
      return;
    case SDK::MessageType::COMMAND_APP_GUI_RESUME:
      message->setResult(SDK::MessageResult::SUCCESS);
      visible = true;
      controls.cancel();
      SDK::send_msg<RideMessage::Request>(kernel);
      break;
    case SDK::MessageType::COMMAND_APP_GUI_SUSPEND:
      message->setResult(SDK::MessageResult::SUCCESS);
      visible = false;
      controls.cancel();
      SDK::send_msg<RideMessage::CancelPreparation>(kernel);
      break;
    case SDK::MessageType::EVENT_GUI_TICK:
      message->setResult(SDK::MessageResult::SUCCESS);
      break;
    case RideMessage::status:
      message->setResult(SDK::MessageResult::SUCCESS);
      state = static_cast<RideMessage::Status *>(message)->state;
      break;
    case SDK::MessageType::EVENT_BUTTON: {
      message->setResult(SDK::MessageResult::SUCCESS);
      auto &button = *static_cast<SDK::Message::EventButton *>(message);
      if (!visible || button.event != SDK::Message::EventButton::Event::CLICK) break;
      if (button.id == SDK::Message::EventButton::Id::SW1 ||
          button.id == SDK::Message::EventButton::Id::SW3) {
        controls.changePage();
      } else if (button.id == SDK::Message::EventButton::Id::SW2) {
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
