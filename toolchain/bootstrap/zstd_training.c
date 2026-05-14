#include <stddef.h>
#include <string.h>

#include "zstd.h"

int main(void) {
    const char payload[] =
        "Hermetic LLVM bootstrap FDO training payload. "
        "This input is intentionally repetitive so zstd's compressor has "
        "enough structure to exercise optimized code generation and LTO. "
        "Hermetic LLVM bootstrap FDO training payload. "
        "This input is intentionally repetitive so zstd's compressor has "
        "enough structure to exercise optimized code generation and LTO.";

    unsigned char compressed[1024] = {0};
    const size_t compressed_size = ZSTD_compress(
        compressed,
        sizeof(compressed),
        payload,
        sizeof(payload),
        19
    );

    if (ZSTD_isError(compressed_size) || compressed_size == 0) {
        return 1;
    }

    char roundtrip[512] = {0};
    const size_t decompressed_size = ZSTD_decompress(
        roundtrip,
        sizeof(roundtrip),
        compressed,
        compressed_size
    );

    if (ZSTD_isError(decompressed_size) || decompressed_size != sizeof(payload)) {
        return 1;
    }

    return memcmp(roundtrip, payload, sizeof(payload)) == 0 ? 0 : 1;
}
