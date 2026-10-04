#include "DisplayConfiguration.hpp"
#include <cassert>
#include <cstdio>
int main() {
  assert(supportsDisplay(240,240,6));
  assert(supportsDisplay(240,240,8));
  assert(!supportsDisplay(240,240,16));
  assert(!supportsDisplay(0,240,6));
  assert(!supportsDisplay(240,-1,6));
  assert(!supportsDisplay(641,240,6));
  std::puts("Display configuration tests passed");
}
