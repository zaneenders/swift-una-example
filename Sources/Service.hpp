#pragma once

#include "SDK/Glance/GlanceControl.hpp"
#include "SDK/Kernel/Kernel.hpp"
#include "RideLogger.hpp"

class Service {
public:
  explicit Service(SDK::Kernel &kernel) : kernel(kernel), logger(kernel) {}
  Service(const Service &) = delete;
  Service &operator=(const Service &) = delete;
  void run();

private:
  void updateStatus();
  SDK::Kernel &kernel;
  SDK::Glance::Form form;
  SDK::Glance::ControlText value;
  RideLogger logger;
};
