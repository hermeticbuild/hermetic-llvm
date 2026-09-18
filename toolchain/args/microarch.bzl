"""Maps the microarchitecture constraints onto compiler flags."""

load("//constraints/march:march_values.bzl", "MARCHES")
load("//constraints/mtune:mtune_values.bzl", "MTUNES")

# Appended after the hardcoded RISC-V `-march=rv64gc` in `target_flags`, so an
# explicit selection wins there too: clang takes the last `-march`.
MARCH_FLAGS = select({
    "//constraints/march:{}".format(march): ["-march={}".format(march)]
    for march in MARCHES
} | {"//conditions:default": []})

MTUNE_FLAGS = select({
    "//constraints/mtune:{}".format(mtune): ["-mtune={}".format(mtune)]
    for mtune in MTUNES
} | {"//conditions:default": []})
