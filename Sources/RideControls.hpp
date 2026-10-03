#pragma once
#include "RideMessages.hpp"

class RideControls {
public:
  enum class Page { Ride, Speed };
  Page page() const { return currentPage; }
  void changePage() { currentPage = currentPage == Page::Ride ? Page::Speed : Page::Ride; }
  enum class Action { None, Start, Save };
  bool confirmingSave() const { return confirmSave; }
  void cancel() { confirmSave = false; }
  Action select(RideMessage::Phase phase) {
    if (phase != RideMessage::Phase::Recording) {
      confirmSave = false;
      return Action::Start;
    }
    if (!confirmSave) {
      confirmSave = true;
      return Action::None;
    }
    confirmSave = false;
    return Action::Save;
  }
private:
  bool confirmSave = false;
  Page currentPage = Page::Ride;
};
