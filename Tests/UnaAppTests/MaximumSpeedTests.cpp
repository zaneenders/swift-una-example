#include "MaximumSpeed.hpp"
#include <cassert>
#include <limits>
#include <cstdio>
int main() {
  MaximumSpeed speed;
  assert(!speed.hasReading());
  speed.add(20, false);
  speed.add(-1, true);
  speed.add(std::numeric_limits<float>::quiet_NaN(), true);
  speed.add(std::numeric_limits<float>::infinity(), true);
  assert(!speed.hasReading());
  speed.add(0, true);
  assert(speed.hasReading() && speed.kilometresPerHour() == 0);
  speed.add(10, true);
  speed.add(5, true);
  assert(std::abs(speed.kilometresPerHour() - 36) < 0.001f);
  speed.add(20, true);
  assert(std::abs(speed.kilometresPerHour() - 72) < 0.001f);
  speed.reset();
  assert(!speed.hasReading() && speed.kilometresPerHour() == 0);
  std::puts("Maximum speed tests passed");
}
