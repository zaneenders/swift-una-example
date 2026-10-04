#pragma once
#include <cmath>

class MaximumSpeed {
public:
  void reset() { available = false; maximum = 0; }
  void add(float metresPerSecond, bool valid) {
    if (!valid || !std::isfinite(metresPerSecond) || metresPerSecond < 0) return;
    available = true;
    if (metresPerSecond > maximum) maximum = metresPerSecond;
  }
  bool hasReading() const { return available; }
  float kilometresPerHour() const { return maximum * 3.6f; }
private:
  bool available = false;
  float maximum = 0;
};
