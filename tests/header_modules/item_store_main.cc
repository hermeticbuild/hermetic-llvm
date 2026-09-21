#include <cstdio>
#include <string>

#include "tests/header_modules/item_store.h"

int main() {
  std::string summary;
  for (const auto& item : item_store::MakeItems(3)) {
    summary += item_store::Describe(item);
  }
  std::printf("%s\n", summary.c_str());
  return summary == "item0(1)item1(2)item2(3)" ? 0 : 1;
}
