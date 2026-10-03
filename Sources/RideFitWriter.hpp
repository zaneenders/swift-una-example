#pragma once
#include "SDK/Fit/FitWriter.hpp"
#include <memory>

// Sample schema: sensor clock (us), stream ID, validity, six Float32 channels.
// Developer fields preserve exact sensor timing independently of FIT UTC seconds.
class RideFitWriter {
public:
  explicit RideFitWriter(SDK::Interface::IFile &file) : writer(file) {}
  bool begin(uint32_t utc);
  bool sample(const uint8_t *encoded);
  bool record(uint32_t utc, bool fix, float latitude, float longitude,
              float altitude, bool speedValid, float speed);
  bool finish(uint32_t utc, uint32_t durationMs);
private:
  SDK::Fit::FitWriter writer;
  uint32_t startUtc = 0;
};
