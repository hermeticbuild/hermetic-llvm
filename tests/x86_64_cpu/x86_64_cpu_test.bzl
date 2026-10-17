load("@platforms_contrib//cpu/x86_64:x86_64.bzl", "x86_64_level_constraints")
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")

_MODEL = str(Label("@platforms_contrib//cpu/x86_64:model"))
_TUNE_CPU = str(Label("//config:x86_64_tune_cpu"))

def _cpu_flags(env, target):
    argv = env.expect.that_target(target).action_named("CppCompile").actual.argv
    return [
        arg
        for arg in argv
        if arg.startswith("-m") and not arg.startswith("-mmacosx-version-min=")
    ]

def _expect_cpu_flags(flags):
    def impl(env, target):
        env.expect.that_collection(_cpu_flags(env, target)).contains_exactly(flags).in_order()

    return impl

def _expect_model_flags(tune_cpu):
    def impl(env, target):
        flags = _cpu_flags(env, target)
        env.expect.that_str(flags[0]).equals("-march=znver4")
        env.expect.that_str(flags[-1]).equals("-mtune=" + tune_cpu)

        # Every feature is explicit, whether -march=znver4 implies it or not.
        env.expect.that_collection(flags).contains_at_least([
            "-mapx-features=egpr",
            "-mavx2",
            "-msse",
            "-mno-avx512f",
            "-mno-amx-tile",
        ])

    return impl

def x86_64_cpu_test_suite(name):
    cc_library(
        name = name + "_subject",
        srcs = ["subject.c"],
        tags = ["manual"],
    )

    linux = ["@platforms//cpu:x86_64", "@platforms//os:linux"]
    platforms = {
        "v3": (linux + x86_64_level_constraints("v3"), ["--{}=znver4".format(_TUNE_CPU)]),
        # E.g. a znver4 in a VM that hides AVX-512.
        "znver4": (linux + x86_64_level_constraints("v3") + [
            "@platforms_contrib//cpu/x86_64/feature:egpr_available",
        ], ["--{}=znver4".format(_MODEL)]),
        "v3_avx512f": (linux + x86_64_level_constraints("v3") + [
            "@platforms_contrib//cpu/x86_64/feature:avx512f_available",
            "@platforms_contrib//cpu/x86_64/feature:egpr_available",
        ], []),
        "v4": (linux + x86_64_level_constraints("v4"), []),
        "partial_v2": (linux + [
            "@platforms_contrib//cpu/x86_64/feature:popcnt_available",
            "@platforms_contrib//cpu/x86_64/feature:sse3_available",
        ], []),
        "macos_popcnt": ([
            "@platforms//cpu:x86_64",
            "@platforms//os:macos",
        ] + [
            "@platforms_contrib//cpu/x86_64/feature:{}_available".format(feature)
            for feature in ["cx16", "popcnt", "sahf", "sse3", "sse4.1", "ssse3"]
        ], []),
        "no_sse": (linux + [
            "@platforms_contrib//cpu/x86_64/feature:mmx_unavailable",
            "@platforms_contrib//cpu/x86_64/feature:sse_unavailable",
        ], []),
    }
    for platform, (constraints, flags) in platforms.items():
        native.platform(
            name = "{}_{}".format(name, platform),
            constraint_values = constraints,
            flags = flags,
        )

    for test, platform, flags in [
        ("default", "//platforms:linux_x86_64", ["-march=x86-64", "-mtune=generic"]),
        # The platform declares the features of clang's default CPU for macOS.
        ("macos", "//platforms:macos_x86_64", ["-march=penryn", "-mtune=generic"]),
        ("macos_popcnt", ":{}_macos_popcnt".format(name), [
            "-march=x86-64",
            "-mcx16",
            "-mpopcnt",
            "-msahf",
            "-msse3",
            "-msse4.1",
            "-mssse3",
            "-mtune=generic",
        ]),
        ("v3", ":{}_v3".format(name), ["-march=x86-64-v3", "-mtune=znver4"]),
        ("v3_avx512f", ":{}_v3_avx512f".format(name), [
            "-march=x86-64-v3",
            "-mavx512f",
            "-mapx-features=egpr",
            "-mtune=generic",
        ]),
        ("v4", ":{}_v4".format(name), ["-march=x86-64-v4", "-mtune=generic"]),
        ("partial_v2", ":{}_partial_v2".format(name), [
            "-march=x86-64",
            "-mpopcnt",
            "-msse3",
            "-mtune=generic",
        ]),
        ("no_sse", ":{}_no_sse".format(name), ["-march=x86-64", "-mno-mmx", "-mno-sse", "-mtune=generic"]),
        ("aarch64", "//platforms:linux_aarch64", []),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_cpu_flags(flags),
            config_settings = {"//command_line_option:platforms": str(Label(platform))},
        )

    for test, platform, settings, impl in [
        ("model", ":{}_znver4".format(name), {}, _expect_model_flags("znver4")),
        ("model_tune_cpu", ":{}_znver4".format(name), {_TUNE_CPU: "icelake-server"}, _expect_model_flags("icelake-server")),
        # @llvm//platforms:linux_x86_64 resets the model, but not the tuning.
        ("reset_model", "//platforms:linux_x86_64", {_MODEL: "znver4"}, _expect_cpu_flags(["-march=x86-64", "-mtune=generic"])),
        ("tune_cpu", "//platforms:linux_x86_64", {_TUNE_CPU: "znver5"}, _expect_cpu_flags(["-march=x86-64", "-mtune=znver5"])),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = impl,
            config_settings = settings | {"//command_line_option:platforms": str(Label(platform))},
        )
