_FEATURE = "@platforms_contrib//cpu/x86_64/feature:"

# The features of @platforms_contrib//cpu/x86_64/feature that clang enables with -m<feature> and
# disables with -mno-<feature>.
_FEATURES = [
    "adx",
    "aes",
    "amx-avx512",
    "amx-bf16",
    "amx-complex",
    "amx-fp16",
    "amx-fp8",
    "amx-int8",
    "amx-movrs",
    "amx-tile",
    "avx",
    "avx10.1",
    "avx10.2",
    "avx2",
    "avx512bf16",
    "avx512bitalg",
    "avx512bmm",
    "avx512bw",
    "avx512cd",
    "avx512dq",
    "avx512f",
    "avx512fp16",
    "avx512ifma",
    "avx512vbmi",
    "avx512vbmi2",
    "avx512vl",
    "avx512vnni",
    "avx512vp2intersect",
    "avx512vpopcntdq",
    "avxifma",
    "avxneconvert",
    "avxvnni",
    "avxvnniint16",
    "avxvnniint8",
    "bmi",
    "bmi2",
    "cldemote",
    "clflushopt",
    "clwb",
    "clzero",
    "cmpccxadd",
    "crc32",
    "cx16",
    "enqcmd",
    "f16c",
    "fma",
    "fma4",
    "fsgsbase",
    "fxsr",
    "gfni",
    "hreset",
    "invpcid",
    "kl",
    "lwp",
    "lzcnt",
    "mmx",
    "movbe",
    "movdir64b",
    "movdiri",
    "movrs",
    "mwaitx",
    "pclmul",
    "pconfig",
    "pku",
    "popcnt",
    "prefetchi",
    "prfchw",
    "ptwrite",
    "raoint",
    "rdpid",
    "rdpru",
    "rdrnd",
    "rdseed",
    "rtm",
    "sahf",
    "serialize",
    "sgx",
    "sha",
    "sha512",
    "shstk",
    "sm3",
    "sm4",
    "sse",
    "sse2",
    "sse3",
    "sse4.1",
    "sse4.2",
    "sse4a",
    "ssse3",
    "tbm",
    "tsxldtrk",
    "uintr",
    "usermsr",
    "vaes",
    "vpclmulqdq",
    "waitpkg",
    "wbnoinvd",
    "widekl",
    "x87",
    "xop",
    "xsave",
    "xsavec",
    "xsaveopt",
    "xsaves",
]

# The APX features of @platforms_contrib//cpu/x86_64/feature, which clang enables with
# -mapx-features=<feature> and disables with -mno-apx-features=<feature>.
_APX_FEATURES = [
    "ccmp",
    "cf",
    "egpr",
    "jmpabs",
    "ndd",
    "nf",
    "ppx",
    "push2pop2",
    "zu",
]

# The flags that make clang enable each feature, without the leading "-m" or "-mno-".
_FEATURE_FLAGS = dict(
    [(feature, feature) for feature in _FEATURES] +
    [(feature, "apx-features=" + feature) for feature in _APX_FEATURES],
)

# The features that -march=x86-64[-<level>] enables in addition to those of the lower levels, as
# defined by LLVM. -march=x86-64 also enables cmov and cx8, which have no constraints since every
# x86-64 CPU has them.
_LEVEL_FEATURES = {
    "v1": ["fxsr", "mmx", "sse", "sse2", "x87"],
    "v2": ["crc32", "cx16", "popcnt", "sahf", "sse3", "sse4.1", "sse4.2", "ssse3"],
    "v3": ["avx", "avx2", "bmi", "bmi2", "f16c", "fma", "lzcnt", "movbe", "xsave"],
    "v4": ["avx512bw", "avx512cd", "avx512dq", "avx512f", "avx512vl"],
}

_LEVEL_OF_FEATURE = {
    feature: level
    for level, features in _LEVEL_FEATURES.items()
    for feature in features
}

# The features of penryn, clang's default CPU for x86-64 macOS, beyond the "v1" level.
MACOS_X86_64_FEATURES = ["cx16", "sahf", "sse3", "sse4.1", "ssse3"]

def _at_least(level):
    return "@platforms_contrib//cpu/x86_64:at_least_" + level

def x86_64_macos_default_cpu(name):
    """Declares a config setting for macOS platforms with exactly the features of penryn.

    With -march=penryn instead of an equivalent -march=x86-64 and feature flags, clang predefines the
    same CPU macros (e.g. __core2__) as for its default CPU.

    Args:
      name: The name of the config setting.
    """
    native.config_setting(
        name = name,
        constraint_values = [
            "@platforms//cpu:x86_64",
            "@platforms//os:macos",
        ] + [
            "{}{}_{}".format(
                _FEATURE,
                feature,
                "available" if feature in _LEVEL_FEATURES["v1"] + MACOS_X86_64_FEATURES else "unavailable",
            )
            for feature in _FEATURE_FLAGS
        ],
    )

def x86_64_all_feature_flags():
    """Selects the flags that enable or disable every feature as the target platform declares.

    Returns:
      The flags, which make the features independent of the -march value before them.
    """
    flags = []
    for feature, flag in _FEATURE_FLAGS.items():
        flags += select({
            _FEATURE + feature: ["-m" + flag],
            _FEATURE + "no_" + feature: ["-mno-" + flag],
            "//conditions:default": [],
        })
    return flags

def x86_64_level_flags(macos_default_cpu):
    """Selects the flags for the features of the target platform.

    The flags don't depend on clang's default CPU for the target, which differs e.g. for macOS.

    Args:
      macos_default_cpu: The config setting declared by x86_64_macos_default_cpu.

    Returns:
      -march for the highest x86-64 level whose features are all available, followed by the flags
      that disable the unavailable features of the "v1" level and enable the available features
      that the level doesn't imply. For macOS platforms with exactly the features of penryn,
      -march=penryn.
    """
    flags = select({
        macos_default_cpu: ["-march=penryn"],
        _at_least("v4"): ["-march=x86-64-v4"],
        _at_least("v3"): ["-march=x86-64-v3"],
        _at_least("v2"): ["-march=x86-64-v2"],
        "@platforms//cpu:x86_64": ["-march=x86-64"],
        "//conditions:default": [],
    })
    for feature, flag in _FEATURE_FLAGS.items():
        level = _LEVEL_OF_FEATURE.get(feature)
        if level == "v1":
            # Implied by every -march value above.
            selection = {_FEATURE + "no_" + feature: ["-mno-" + flag]}
        elif level:
            selection = {
                _at_least(level): [],
                _FEATURE + feature: ["-m" + flag],
            }
            if feature in MACOS_X86_64_FEATURES:
                selection[macos_default_cpu] = []
        else:
            selection = {_FEATURE + feature: ["-m" + flag]}
        flags += select(selection | {"//conditions:default": []})
    return flags
