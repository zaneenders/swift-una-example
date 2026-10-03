#pragma once
#include "SDK/Kernel/Kernel.hpp"
#include "RideMessages.hpp"
#include "RideControls.hpp"
#include <vector>
class Gui {
public:
  explicit Gui(SDK::Kernel &kernel) : kernel(kernel) {}
  void run();
private:
  void draw();
  void text(int x, int y, const char *text, uint8_t color = 0xFF, int scale = 2);
  void centered(int y, const char *label, uint8_t color = 0xFF, int scale = 2);
  void centeredAt(int centerX, int y, int availableWidth, const char *label, uint8_t color, int scale);
  SDK::Kernel &kernel;
  RideMessage::State state;
  std::vector<uint8_t> pixels;
  int width = 0, height = 0;
  bool visible = false;
  RideControls controls;
};
