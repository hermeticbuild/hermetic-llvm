#include <stdio.h>
#include <linux/version.h>

/* Polyfill for older kernel versions */
#ifndef LINUX_VERSION_MAJOR
#define LINUX_VERSION_MAJOR (LINUX_VERSION_CODE >> 16)
#endif

#ifndef LINUX_VERSION_PATCHLEVEL
#define LINUX_VERSION_PATCHLEVEL ((LINUX_VERSION_CODE >> 8) & 0xFF)
#endif

#ifndef LINUX_VERSION_SUBLEVEL
#define LINUX_VERSION_SUBLEVEL (LINUX_VERSION_CODE & 0xFF)
#endif

#if LINUX_VERSION_MAJOR != 5
#error "Expected Linux kernel headers major version 5"
#endif

#if LINUX_VERSION_PATCHLEVEL != 4
#error "Expected Linux kernel headers minor version 4"
#endif

int main(void) {
    printf("Linux kernel version: %d.%d.%d\n",
           LINUX_VERSION_MAJOR, LINUX_VERSION_PATCHLEVEL, LINUX_VERSION_SUBLEVEL);
    return 0;
}
