#include <vector>
#if !defined(_MSC_VER) && !defined(HERMETIC_USER_VECTOR_HEADER)
#error Target includes must precede C++ library headers
#endif
#if defined(_MSC_VER) && defined(HERMETIC_USER_VECTOR_HEADER)
#error C++ library headers must precede target includes on MSVC
#endif
#include <cmath>
#include <cstdlib>
int header_precedence_cxx() { return std::vector<int>{1, 2}.size(); }
