"""
The aarch64 outline atomic helpers built from lib/builtins/aarch64/lse.S.

Each (pat, size, model) gets its own lse_<pat>_<size>_<model>.S copy, written
when llvm-project is fetched, so cc_static_library sees distinct object names.
"""

LSE_ATOMIC_VARIANTS = [
    (pat, size, model)
    for pat in [
        "cas",
        "swp",
        "ldadd",
        "ldclr",
        "ldeor",
        "ldset",
    ]
    for size in [
        1,
        2,
        4,
        8,
        16,
    ]
    for model in [
        1,
        2,
        3,
        4,
        5,
    ]
    if pat == "cas" or size != 16
]
