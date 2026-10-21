#include <cstdio>

extern "C" int windows_msvc_legacy_stdio(void);

// This must fail to link: the C++ stdio header selects ISO-wide mode, while
// the extracted legacy stdio definitions require legacy-wide mode.
int main() { return windows_msvc_legacy_stdio() != 42; }
