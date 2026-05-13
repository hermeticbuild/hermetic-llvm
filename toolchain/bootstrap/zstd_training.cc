#include <array>
#include <cstddef>
#include <cstring>
#include <string_view>

#include "zstd.h"

int main() {
    constexpr std::string_view payload =
        "Hermetic LLVM bootstrap FDO training payload. "
        "This input is intentionally repetitive so zstd's compressor has "
        "enough structure to exercise optimized code generation and LTO. "
        "Hermetic LLVM bootstrap FDO training payload. "
        "This input is intentionally repetitive so zstd's compressor has "
        "enough structure to exercise optimized code generation and LTO.";

    std::array<unsigned char, 1024> compressed = {};
    const std::size_t compressed_size = ZSTD_compress(
        compressed.data(),
        compressed.size(),
        payload.data(),
        payload.size(),
        19
    );

    if (ZSTD_isError(compressed_size) || compressed_size == 0) {
        return 1;
    }

    std::array<char, 512> roundtrip = {};
    const std::size_t decompressed_size = ZSTD_decompress(
        roundtrip.data(),
        roundtrip.size(),
        compressed.data(),
        compressed_size
    );

    if (ZSTD_isError(decompressed_size) || decompressed_size != payload.size()) {
        return 1;
    }

    return std::memcmp(roundtrip.data(), payload.data(), payload.size()) == 0 ? 0 : 1;
}
