#include <limits.h>

// Clang's limits.h supplies C23 widths and includes wasi-libc's limits.h next.
// Searching libc first loses the widths; omitting libc loses its UTF-8 limit.
_Static_assert(INT_WIDTH == sizeof(int) * CHAR_BIT, "C23 integer width");
_Static_assert(BITINT_MAXWIDTH >= 128, "C23 bit-precise integer support");
_Static_assert(MB_LEN_MAX == 4, "wasi-libc multibyte character limit");
