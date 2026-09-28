#pragma once

#include <cstddef>
#include <string>
#include <utility>
#include <vector>

namespace item_store {

struct Item {
  std::string name;
  std::vector<int> values;
};

std::string Describe(const Item &item);

// Instantiate vector members in the module so codegen must provide their
// definitions to importers.
inline std::vector<Item> MakeItems(int n) {
  std::vector<Item> items;
  items.reserve(static_cast<std::size_t>(n));
  for (int i = 0; i < n; ++i) {
    Item item;
    item.name = "item" + std::to_string(i);
    item.values.assign(static_cast<std::size_t>(i) + 1, i);
    items.push_back(std::move(item));
  }
  return items;
}

} // namespace item_store
