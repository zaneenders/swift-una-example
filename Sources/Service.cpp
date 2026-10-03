#include "Service.hpp"

#include "SDK/Messages/CommandMessages.hpp"
#include "SDK/Messages/MessageBase.hpp"
#include "SDK/Messages/MessageGuard.hpp"
#include "SDK/Messages/MessageTypes.hpp"

#include <cstdint>

namespace {
extern "C" void printGlanceText(void *context, const uint8_t *text,
                                uint32_t length) {
  auto &control = *static_cast<SDK::Glance::ControlText *>(context);
  control.print("%.*s", static_cast<int>(length),
                reinterpret_cast<const char *>(text));
}
} // namespace

void Service::run() {
  while (true) {
    SDK::MessageBase *message = nullptr;
    if (!kernel.comm.getMessage(message))
      continue;

    switch (message->getType()) {
    case SDK::MessageType::EVENT_GLANCE_START: {
      const auto birdWidth = swift_bird_width();
      const auto birdHeight = swift_bird_height();
      if (auto config =
              SDK::make_msg<SDK::Message::RequestGlanceConfig>(kernel)) {
        if (config.send(100) && config.ok() && config->maxControls >= 2 &&
            config->width >= birdWidth + 120 && config->height >= birdHeight) {
          form.setWidth(config->width);
          form.setHeight(config->height);
          birdPixels.resize(static_cast<size_t>(birdWidth) * birdHeight);
          if (swift_bird_copy(birdPixels.data(), birdPixels.size()) !=
              birdPixels.size())
            break;
          bird = form.createImage();
          bird.init({0, swift_bird_y(&state, config->height)},
                    {birdWidth, birdHeight}, birdPixels.data());
          value = form.createText();
          value
              .pos({birdWidth, 0},
                   {static_cast<uint16_t>(config->width - birdWidth),
                    static_cast<uint16_t>(config->height)})
              .font(GlanceFont_t::GLANCE_FONT_POPPINS_SEMIBOLD_30)
              .color(GlanceColor_t::GLANCE_COLOR_WHITE)
              .alignment(GlanceAlignH_t::GLANCE_ALIGN_H_CENTER);
          swift_glance_render_text(&value, printGlanceText);
        }
      }
      break;
    }

    case SDK::MessageType::EVENT_GLANCE_TICK:
      if (form.size() == 0)
        break;
      swift_glance_advance(&state);
      bird.pos({0, swift_bird_y(&state, form.getHeight())});
      swift_glance_render_text(&value, printGlanceText);
      if (auto update =
              SDK::make_msg<SDK::Message::RequestGlanceUpdate>(kernel)) {
        update->name = APP_NAME;
        update->controls = form.data();
        update->controlsNumber = static_cast<uint32_t>(form.size());
        if (update.send(100) && update.ok())
          form.setValid();
      }
      break;

    case SDK::MessageType::EVENT_GLANCE_STOP:
    case SDK::MessageType::COMMAND_APP_STOP:
      kernel.comm.releaseMessage(message);
      return;

    default:
      break;
    }
    kernel.comm.releaseMessage(message);
  }
}
