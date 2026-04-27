#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    static constexpr char kSeed[] = "hello";

    if (size != sizeof(kSeed) - 1 || std::memcmp(data, kSeed, sizeof(kSeed) - 1) != 0) {
        return 0;
    }

    const char *output_path = std::getenv("LLVM_FUZZER_OUTPUT");
    if (!output_path) {
        return 0;
    }

    std::ofstream output(output_path, std::ios::binary);
    output.write(reinterpret_cast<const char *>(data), static_cast<std::streamsize>(size));
    return 0;
}
