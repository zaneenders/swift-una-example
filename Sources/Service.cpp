#include "Service.hpp"

#include "SDK/Messages/CommandMessages.hpp"
#include "SDK/Messages/MessageBase.hpp"
#include "SDK/Messages/MessageGuard.hpp"
#include "SDK/Messages/MessageTypes.hpp"

#include <cstdint>

extern "C" uint32_t swift_next_tick(uint32_t tick);

void Service::run()
{
    while (true) {
        SDK::MessageBase *message = nullptr;
        if (!kernel.comm.getMessage(message)) continue;

        switch (message->getType()) {
        case SDK::MessageType::EVENT_GLANCE_START:
            if (auto config = SDK::make_msg<SDK::Message::RequestGlanceConfig>(kernel)) {
                if (config.send(100) && config.ok() && config->maxControls >= 1
                    && config->width > 0 && config->height > 0) {
                    form.setWidth(config->width);
                    form.setHeight(config->height);
                    value = form.createText();
                    value.pos({0, 0}, {static_cast<uint16_t>(config->width),
                                       static_cast<uint16_t>(config->height)})
                        .font(GlanceFont_t::GLANCE_FONT_POPPINS_SEMIBOLD_30)
                        .color(GlanceColor_t::GLANCE_COLOR_WHITE)
                        .alignment(GlanceAlignH_t::GLANCE_ALIGN_H_CENTER);
                    value.print("Swift %lu", static_cast<unsigned long>(tick));
                }
            }
            break;

        case SDK::MessageType::EVENT_GLANCE_TICK:
            if (form.size() == 0) break;
            tick = swift_next_tick(tick);
            value.print("Swift %lu", static_cast<unsigned long>(tick));
            if (auto update = SDK::make_msg<SDK::Message::RequestGlanceUpdate>(kernel)) {
                update->name = APP_NAME;
                update->controls = form.data();
                update->controlsNumber = static_cast<uint32_t>(form.size());
                if (update.send(100) && update.ok()) form.setValid();
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
