#pragma once

#include "SDK/Kernel/Kernel.hpp"
#include "SDK/SensorLayer/SensorConnection.hpp"
#include "SDK/Messages/SensorLayerMessages.hpp"
#include "RideFitWriter.hpp"
#include <memory>

class RideLogger {
public:
  explicit RideLogger(SDK::Kernel &kernel) : kernel(kernel) {}
  ~RideLogger() { stop(); }
  bool start();
  void stop();
  void receive(const SDK::Message::Sensor::EventData &event);
  void tick();
  bool failed() const { return error; }
  bool connected() {
    return acceleration.isConnected() && rotation.isConnected() &&
           location.isConnected() && speed.isConnected() &&
           pressure.isConnected() && magnetic.isConnected() && distance.isConnected();
  }

private:
  void append(uint64_t timestamp, uint32_t kind, bool valid,
              float a, float b, float c = 0, float d = 0);
  SDK::Kernel &kernel;
  SDK::Sensor::Connection acceleration{SDK::Sensor::Type::ACCELEROMETER, 20, 200};
  SDK::Sensor::Connection rotation{SDK::Sensor::Type::GYROSCOPE, 20, 200};
  SDK::Sensor::Connection location{SDK::Sensor::Type::GPS_LOCATION, 1000, 1000};
  SDK::Sensor::Connection speed{SDK::Sensor::Type::GPS_SPEED, 1000, 1000};
  std::unique_ptr<SDK::Interface::IFile> file;
  SDK::Sensor::Connection pressure{SDK::Sensor::Type::PRESSURE, 100, 200};
  SDK::Sensor::Connection magnetic{SDK::Sensor::Type::MAGNETIC_FIELD, 50, 200};
  SDK::Sensor::Connection distance{SDK::Sensor::Type::GPS_DISTANCE, 1000, 1000};
  std::unique_ptr<RideFitWriter> fit;
  uint32_t startMs = 0;
  uint32_t lastLocationMs = 0, lastSpeedMs = 0;
  bool fix = false, speedValid = false;
  float latitude = 0, longitude = 0, altitude = 0, speedMps = 0;
  bool error = false;
  unsigned ticks = 0;
};
