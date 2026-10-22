#include <cstdio>

extern "C" int windows_msvc_legacy_stdio(void);

// This must fail to link: the toolchain selects ISO-wide mode, which the C++
// stdio header records. The legacy sscanf implementation requires legacy-wide
// support instead.
int main() { return windows_msvc_legacy_stdio() != 42; }
