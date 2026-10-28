#include <cstdio>

extern "C" int filesystem_abi0();
extern "C" int filesystem_abi1();

int main() {
  int result = filesystem_abi0();
  if (result) {
    std::fprintf(stderr, "filesystem ABI 0 failed at check %d\n", result);
    return result;
  }
  result = filesystem_abi1();
  if (result)
    std::fprintf(stderr, "filesystem ABI 1 failed at check %d\n", result);
  return result;
}
