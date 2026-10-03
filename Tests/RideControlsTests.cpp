#include "RideControls.hpp"
#include <cassert>
#include <cstdio>
int main() {
  using Action = RideControls::Action;
  using Phase = RideMessage::Phase;
  RideControls controls;
  assert(controls.page() == RideControls::Page::Ride);
  controls.changePage();
  assert(controls.page() == RideControls::Page::Speed);
  controls.changePage();
  assert(controls.page() == RideControls::Page::Ride);
  assert(controls.select(Phase::Ready) == Action::Start);
  assert(controls.select(Phase::Recording) == Action::None);
  assert(controls.confirmingSave());
  controls.changePage();
  assert(controls.confirmingSave());
  controls.cancel();
  assert(!controls.confirmingSave());
  assert(controls.select(Phase::Recording) == Action::None);
  assert(controls.select(Phase::Recording) == Action::Save);
  assert(!controls.confirmingSave());
  assert(controls.select(Phase::Saved) == Action::Start);
  assert(controls.select(Phase::Error) == Action::Start);
  std::puts("Ride controls tests passed");
}
