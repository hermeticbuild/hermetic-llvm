#include "tests/header_modules/item_store.h"

#include <sstream>

namespace item_store {

std::string Describe(const Item& item) {
  std::ostringstream oss;
  oss << item.name << "(" << item.values.size() << ")";
  return oss.str();
}

}  // namespace item_store
