#include <error.h>
#ifndef HERMETIC_USER_ERROR_HEADER
#error Target includes must precede libc headers
#endif
#include <stddef.h>
size_t header_precedence_c(void) { return sizeof(void*); }
#ifdef _WIN32
#include <windows.h>
#ifndef HERMETIC_USER_WINDOWS_HEADER
#error Target includes must precede SDK headers
#endif
#endif
