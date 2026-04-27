#include <cstddef>
#include <cstdint>
#include <cstring>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    static constexpr char kTrigger[] = "ASAN";

    if (size != sizeof(kTrigger) - 1 || std::memcmp(data, kTrigger, sizeof(kTrigger) - 1) != 0) {
        return 0;
    }

    int *buffer = new int[1];
    buffer[0] = 7;
    delete[] buffer;
    return buffer[0];
}
