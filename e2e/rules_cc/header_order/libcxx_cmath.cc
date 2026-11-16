#include <cmath>
#include <type_traits>

static_assert(std::is_same_v<decltype(std::sqrt(4.0f)), float>);
static_assert(std::is_same_v<decltype(std::sqrt(4.0)), double>);
