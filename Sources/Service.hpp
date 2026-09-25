#pragma once

#include "SDK/Glance/GlanceControl.hpp"
#include "SDK/Kernel/Kernel.hpp"

class Service {
public:
    explicit Service(SDK::Kernel &kernel) : kernel(kernel) {}
    void run();

private:
    SDK::Kernel &kernel;
    SDK::Glance::Form form;
    SDK::Glance::ControlText value;
    uint32_t tick = 0;
};
