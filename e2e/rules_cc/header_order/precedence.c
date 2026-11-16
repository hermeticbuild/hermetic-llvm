#include <stdlib.h>
#ifndef HERMETIC_USER_STDLIB_HEADER
#error Target includes must precede libc headers
#endif
#include <stddef.h>
#if !defined(_MSC_VER) && !defined(HERMETIC_USER_STDDEF_HEADER)
#error Target includes must precede builtin headers
#endif
#if defined(_MSC_VER) && defined(HERMETIC_USER_STDDEF_HEADER)
#error Builtin headers must precede target includes on MSVC
#endif
size_t header_precedence_c(void) { return sizeof(void*); }
int header_precedence_has_malloc(void) { return sizeof(&malloc) != 0; }
#ifdef _WIN32
#include <windows.h>
#ifndef HERMETIC_USER_WINDOWS_HEADER
#error Target includes must precede SDK headers
#endif
DWORD header_precedence_windows(void) { return 0; }
#endif
