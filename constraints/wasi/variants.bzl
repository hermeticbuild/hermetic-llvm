"""Supported wasi-libc target triples."""

WASI_TARGET_TRIPLES = {
    "p1": "wasm32-wasip1",
    "p1_threads": "wasm32-wasip1-threads",
    "p2": "wasm32-wasip2",
    "p3": "wasm32-wasip3",
}

WASI_TARGET_TRIPLES_BY_CONFIG = {
    "@llvm//platforms/config:wasi_wasm32_" + variant: triple
    for variant, triple in WASI_TARGET_TRIPLES.items()
}
