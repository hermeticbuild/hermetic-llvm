#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace {

int executable_marker;

void check(bool condition, const char *message) {
  if (!condition) {
    fprintf(stderr, "%s\n", message);
    exit(1);
  }
}

template <typename T> T symbol(const char *name) {
  void *address = dlsym(RTLD_DEFAULT, name);
  check(address != nullptr, name);
  return reinterpret_cast<T>(address);
}

} // namespace

int main() {
  Dl_info executable_info;
  check(dladdr(&executable_marker, &executable_info) != 0, "locate executable");

  // Resolve by name so undefined allocator references do not pull the runtime
  // from its archive or cause these symbols to be exported automatically.
  const char *allocator_symbols[] = {"malloc",
                                     "free",
                                     "_Znwm",
                                     "_ZdlPv",
                                     "_ZnwmSt11align_val_t",
                                     "_ZdlPvmSt11align_val_t"};
  for (const char *name : allocator_symbols) {
    Dl_info symbol_info;
    void *address = symbol<void *>(name);
    check(dladdr(address, &symbol_info) != 0, name);
    check(symbol_info.dli_fbase == executable_info.dli_fbase, name);
  }

  // Allocation alone also succeeds with libc; Scudo identifies its malloc_info
  // output with this version string.
  char *xml = nullptr;
  size_t xml_size = 0;
  FILE *stream = open_memstream(&xml, &xml_size);
  check(stream != nullptr, "open_memstream");
  auto malloc_info = symbol<int (*)(int, FILE *)>("malloc_info");
  check(malloc_info(0, stream) == 0, "malloc_info");
  check(fclose(stream) == 0, "fclose");
  constexpr char scudo_prefix[] = "<malloc version=\"scudo-1\">";
  check(strncmp(xml, scudo_prefix, sizeof(scudo_prefix) - 1) == 0,
        "Scudo malloc_info signature");
  symbol<void (*)(void *)>("free")(xml);
  return 0;
}
