#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstring>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    static constexpr char kTrigger[] = "UBSAN";

    if (size != sizeof(kTrigger) - 1 || std::memcmp(data, kTrigger, sizeof(kTrigger) - 1) != 0) {
        return 0;
    }

    volatile int max = INT_MAX;
    volatile int one = 1;
    return max + one;
}
