#include <stdio.h>

#if __COSMOPOLITAN__ != 400000002
#error Expected the Cosmopolitan 4.0.2 headers
#endif

int exchange_c_tls(int next) {
    static _Thread_local int value = 42;
    int previous = value;
    value = next;
    return previous;
}
