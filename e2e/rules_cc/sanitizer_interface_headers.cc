#include <sanitizer/common_interface_defs.h>

void sanitizer_interface_headers() {
  __sanitizer_print_stack_trace();
}
