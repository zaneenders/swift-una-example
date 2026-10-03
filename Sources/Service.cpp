#include "Service.hpp"
#include "SDK/Messages/CommandMessages.hpp"
#include "SDK/Messages/MessageGuard.hpp"

void Service::publish() {
  if (guiLoaded) SDK::send_msg<RideMessage::Status>(kernel, logger.status());
}

void Service::run() {
  auto lastTick = kernel.sys.getTimeMs();
  const auto launched = lastTick;
  while (true) {
    SDK::MessageBase *message = nullptr;
    if (kernel.comm.getMessage(message, 100)) {
      switch (message->getType()) {
      case SDK::MessageType::COMMAND_APP_STOP:
        logger.stop();
        kernel.comm.releaseMessage(message);
        return;
      case SDK::MessageType::COMMAND_APP_NOTIF_GUI_RUN:
        guiLoaded = true;
        if (logger.status().phase == RideMessage::Phase::Ready) logger.prepareGps();
        publish();
        break;
      case SDK::MessageType::COMMAND_APP_NOTIF_GUI_STOP:
        guiLoaded = false;
        if (logger.status().phase != RideMessage::Phase::Recording) logger.stop();
        break;
      case RideMessage::cancelPreparation:
        if (logger.status().phase != RideMessage::Phase::Recording) logger.stop();
        break;
      case RideMessage::start:
        if (logger.status().phase != RideMessage::Phase::Recording) {
          if (logger.failed()) logger.stop();
          logger.start();
        }
        publish();
        break;
      case RideMessage::stop:
        logger.stop();
        publish();
        break;
      case RideMessage::request:
        if (logger.status().phase == RideMessage::Phase::Ready) logger.prepareGps();
        publish();
        break;
      case SDK::MessageType::EVENT_SENSOR_LAYER_DATA:
        logger.receive(*static_cast<SDK::Message::Sensor::EventData *>(message));
        break;
      default: break;
      }
      kernel.comm.releaseMessage(message);
    }
    const auto now = kernel.sys.getTimeMs();
    if (now - lastTick >= 1000) {
      lastTick = now;
      logger.tick();
      publish();
    }
    if (!guiLoaded && now - launched > 5000 &&
        logger.status().phase != RideMessage::Phase::Recording) return;
  }
}
