"""`-march=` values selectable via `//constraints/march`."""

# Each entry declares a constraint_value named after the string passed to
# `-march=`.
MARCHES = [
    # x86-64 microarchitecture levels.
    # https://en.wikipedia.org/wiki/X86-64#Microarchitecture_levels
    "x86-64",
    "x86-64-v2",
    "x86-64-v3",
    "x86-64-v4",
    # AArch64. `+feature` suffixes are part of the `-march=` value rather than a
    # separate axis, so each combination needs its own value.
    "armv8-a",
    "armv8-a+crc+crypto",
    "armv8.2-a",
    "armv8.2-a+crypto",
]
