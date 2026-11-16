#ifndef HERMETIC_LLVM_E2E_WINDOWS_MSVC_LIBCXX_BEHAVIOR_SUPPORT_H_
#define HERMETIC_LLVM_E2E_WINDOWS_MSVC_LIBCXX_BEHAVIOR_SUPPORT_H_

extern "C" int windows_msvc_alwayslink_marker();
extern "C" int windows_msvc_library_filesystem();
extern "C" void windows_msvc_register_alwayslink();
extern "C" int windows_msvc_ordinary_add(int left, int right);
extern "C" unsigned long long windows_msvc_wide_divide(
    unsigned long long high,
    unsigned long long low,
    unsigned long long divisor);

#endif
