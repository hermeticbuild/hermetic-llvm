#include <linux/version.h>

#if LINUX_VERSION_CODE != EXPECTED_KERNEL_VERSION
#error "Unexpected Linux kernel headers version"
#endif
