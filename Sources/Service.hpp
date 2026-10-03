#pragma once

#include "SDK/Glance/GlanceControl.hpp"
#include "SDK/Kernel/Kernel.hpp"
#include "SwiftBridge.hpp"

class Service {
public:
  explicit Service(SDK::Kernel &kernel) : kernel(kernel) {
    swift_glance_initialize(&state);
  }
  Service(const Service &) = delete;
  Service &operator=(const Service &) = delete;
  void run();

private:
  SDK::Kernel &kernel;
  SDK::Glance::Form form;
  SDK::Glance::ControlText value;
  SDK::Glance::ControlImage bird;
  std::vector<uint8_t> birdPixels;
  uint32_t state;
};
