#pragma once
#include "SDK/Kernel/Kernel.hpp"
#include "RideLogger.hpp"
class Service {
public:
  explicit Service(SDK::Kernel &kernel) : kernel(kernel), logger(kernel) {}
  void run();
private:
  void publish();
  SDK::Kernel &kernel;
  RideLogger logger;
  bool guiLoaded = false;
};
