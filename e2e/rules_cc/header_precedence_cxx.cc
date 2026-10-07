#include <vector>
#if !defined(_MSC_VER) && !defined(HERMETIC_USER_VECTOR_HEADER)
#error Target includes must precede C++ library headers
#endif
#include <cmath>
#include <cstdlib>
int header_precedence_cxx() { return std::vector<int>{1, 2}.size(); }
