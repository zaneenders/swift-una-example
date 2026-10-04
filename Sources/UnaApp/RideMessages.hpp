#pragma once
#include "SDK/Messages/MessageBase.hpp"
namespace RideMessage {
constexpr uint32_t start = 1, stop = 2, request = 3, status = 4, cancelPreparation = 5;
enum class Phase : uint8_t { Ready, Recording, Saved, Error };
struct State {
  Phase phase = Phase::Ready;
  uint32_t elapsedSeconds = 0;
  float maxSpeedKmh = 0;
  float latitude = 0, longitude = 0;
  float accelerationMagnitude = 0, gyroMagnitude = 0;
  bool maxSpeedAvailable = false;
  uint32_t accelerationCount = 0, gyroCount = 0;
  bool accelerationLive = false, gyroLive = false, gpsFix = false;
};
struct CancelPreparation : SDK::MessageBase { CancelPreparation() : MessageBase(cancelPreparation) {} };
struct Start : SDK::MessageBase { Start() : MessageBase(start) {} };
struct Stop : SDK::MessageBase { Stop() : MessageBase(stop) {} };
struct Request : SDK::MessageBase { Request() : MessageBase(request) {} };
struct Status : SDK::MessageBase {
  State state;
  explicit Status(State state) : MessageBase(status), state(state) {}
};
static_assert(sizeof(Status) <= 256);
}
