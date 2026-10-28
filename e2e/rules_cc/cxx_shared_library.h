#ifndef CXX_SHARED_LIBRARY_H_
#define CXX_SHARED_LIBRARY_H_

#include <stdexcept>

// MinGW relies on auto-export and auto-import instead.
#ifdef _MSC_VER
#ifdef CXX_SHARED_LIBRARY_IMPLEMENTATION
#define CXX_SHARED_LIBRARY_API __declspec(dllexport)
#else
#define CXX_SHARED_LIBRARY_API __declspec(dllimport)
#endif
#else
#define CXX_SHARED_LIBRARY_API
#endif

struct CXX_SHARED_LIBRARY_API Shape {
  virtual ~Shape();
  virtual int sides() const;
  static int created;
};

extern CXX_SHARED_LIBRARY_API const int kPrimes[3];

CXX_SHARED_LIBRARY_API int make_and_count();

CXX_SHARED_LIBRARY_API void throw_out_of_range();

#endif  // CXX_SHARED_LIBRARY_H_
