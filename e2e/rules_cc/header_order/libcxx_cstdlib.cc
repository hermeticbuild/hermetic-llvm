#include <cstdlib>

static_assert(sizeof(std::div(7L, 3L).quot) == sizeof(long));
static_assert(sizeof(decltype(&std::malloc)) > 0);
