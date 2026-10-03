#include "RideLogger.hpp"
#include "SwiftBridge.hpp"
#include "SDK/SensorLayer/SensorDataBatch.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserAccelerometer.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserGyroscope.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserGpsLocation.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserGpsSpeed.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserPressure.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserMagneticField.hpp"
#include "SDK/SensorLayer/DataParsers/SensorDataParserGpsDistance.hpp"
#include <cstdio>
#include <ctime>

bool RideLogger::start() {
  if (file)
    return !error;
  error = false;
  fix = false;
  speedValid = false;
  ticks = 0;
  if (!kernel.fs.mkdir("Rides")) {
    error = true;
    return false;
  }
  char path[80];
  bool available = false;
  for (unsigned sequence = 0; sequence < 1000; ++sequence) {
    std::snprintf(path, sizeof(path), "Rides/ride_%llu_%u.fit",
                  static_cast<unsigned long long>(std::time(nullptr)), sequence);
    if (!kernel.fs.exist(path)) {
      available = true;
      break;
    }
  }
  if (!available) {
    error = true;
    return false;
  }
  file = kernel.fs.file(path);
  if (!file || !file->open(true, false)) {
    file.reset();
    error = true;
    return false;
  }
  startMs = kernel.sys.getTimeMs();
  fit = std::make_unique<RideFitWriter>(*file);
  if (!fit->begin(static_cast<uint32_t>(std::time(nullptr))) || !file->flush()) {
    error = true;
    stop();
    return false;
  }
  tick();
  return true;
}

void RideLogger::stop() {
  acceleration.disconnect();
  rotation.disconnect();
  location.disconnect();
  speed.disconnect();
  pressure.disconnect();
  magnetic.disconnect();
  distance.disconnect();
  if (file) {
    if (!error && fit && !fit->finish(static_cast<uint32_t>(std::time(nullptr)),
                                      kernel.sys.getTimeMs() - startMs)) error = true;
    fit.reset();
    if (!file->flush()) error = true;
    if (!file->close()) error = true;
    file.reset();
  }
}

void RideLogger::tick() {
  if (!file || error) return;
  // Retry unsuccessful subscriptions, including the SDK's startup connect race.
  if (!acceleration.isConnected()) acceleration.connect();
  if (!rotation.isConnected()) rotation.connect();
  if (!location.isConnected()) location.connect();
  if (!speed.isConnected()) speed.connect();
  if (!pressure.isConnected()) pressure.connect();
  if (!magnetic.isConnected()) magnetic.connect();
  if (!distance.isConnected()) distance.connect();
  const auto now = kernel.sys.getTimeMs();
  const auto utc = static_cast<uint32_t>(std::time(nullptr));
  append(static_cast<uint64_t>(now)*1000, 8, true,
         static_cast<float>(utc >> 16), static_cast<float>(utc & 0xFFFF));
  if (!fit->record(static_cast<uint32_t>(std::time(nullptr)),
                   fix && now - lastLocationMs < 3000, latitude, longitude, altitude,
                   speedValid && now - lastSpeedMs < 3000, speedMps)) error = true;
  if (++ticks % 5 == 0 && !file->flush()) error = true;
}

void RideLogger::append(uint64_t timestamp, uint32_t kind, bool valid,
                        float a, float b, float c, float d) {
  if (!file || error) return;
  uint8_t encoded[40];
  swift_ride_encode(encoded, timestamp, kind, valid ? 1 : 0,
                    a, b, c, d, 0, 0);
  if (!fit->sample(encoded)) error = true;
}

void RideLogger::receive(const SDK::Message::Sensor::EventData &event) {
  if (!file || error) return;
  SDK::Sensor::DataBatch batch(event.data, event.count, event.stride);
  for (uint16_t index = 0; index < batch.size(); ++index) {
    auto sample = batch[index];
    const auto timestamp = sample.getTimestampUs();
    if (acceleration.matchesDriver(event.handle)) {
      SDK::SensorDataParser::Accelerometer parser(sample);
      append(timestamp, 1, parser.isDataValid(), parser.getX(), parser.getY(), parser.getZ());
    } else if (rotation.matchesDriver(event.handle)) {
      SDK::SensorDataParser::Gyroscope parser(sample);
      append(timestamp, 2, parser.isDataValid(), parser.getX(), parser.getY(), parser.getZ());
    } else if (location.matchesDriver(event.handle)) {
      SDK::SensorDataParser::GpsLocation parser(sample);
      fix = parser.isCoordinatesValid();
      latitude = parser.getLatitude();
      longitude = parser.getLongitude();
      altitude = parser.getAltitude();
      lastLocationMs = kernel.sys.getTimeMs();
      append(timestamp, 3, parser.isCoordinatesValid(), parser.getLatitude(),
             parser.getLongitude(), parser.getAltitude(), parser.getPrecision());
    } else if (speed.matchesDriver(event.handle)) {
      SDK::SensorDataParser::GpsSpeed parser(sample);
      speedValid = parser.isSpeedValid();
      speedMps = parser.getSpeed();
      lastSpeedMs = kernel.sys.getTimeMs();
      append(timestamp, 4, parser.isSpeedValid(), parser.getSpeed(), 0);
    } else if (pressure.matchesDriver(event.handle)) {
      SDK::SensorDataParser::Pressure parser(sample);
      append(timestamp, 5, parser.isDataValid(), parser.getPressure(), parser.getP0(), parser.getAltitude());
    } else if (magnetic.matchesDriver(event.handle)) {
      SDK::SensorDataParser::MagneticField parser(sample);
      append(timestamp, 6, parser.isDataValid(), parser.getX(), parser.getY(), parser.getZ(),
             parser.isCalibrated() ? 1 : 0);
    } else if (distance.matchesDriver(event.handle)) {
      SDK::SensorDataParser::GpsDistance parser(sample);
      append(timestamp, 7, parser.isDataValid(), parser.getDistance(), 0);
    }
  }
}
