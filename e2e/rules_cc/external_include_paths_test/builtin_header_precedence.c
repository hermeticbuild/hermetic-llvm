#include <stddef.h>

#ifndef HERMETIC_EXTERNAL_STDDEF_HEADER
#error External include paths must precede compiler builtin headers
#endif

size_t external_header_precedence(void) { return sizeof(void*); }
