#pragma once

#include <string>
#include <vector>

namespace item_store {

struct Item {
  std::string name;
  std::vector<int> values;
};

std::string Describe(const Item& item);

// Instantiates std::vector<Item> member functions inside this module: with
// module codegen, importing translation units rely on the object file
// compiled from this module to provide them.
inline std::vector<Item> MakeItems(int n) {
  std::vector<Item> items;
  items.reserve(static_cast<size_t>(n));
  for (int i = 0; i < n; ++i) {
    Item item;
    item.name = "item" + std::to_string(i);
    item.values.assign(static_cast<size_t>(i) + 1, i);
    items.push_back(std::move(item));
  }
  return items;
}

}  // namespace item_store
