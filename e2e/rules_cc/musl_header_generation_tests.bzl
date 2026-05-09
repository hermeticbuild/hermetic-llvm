load("@bazel_skylib//rules:diff_test.bzl", "diff_test")

_ARCHES = [
    "x86_64",
    "aarch64",
    "riscv64",
    "s390x",
]

_SED_COMPATIBLE_WITH = select({
    "@platforms//os:windows": ["@platforms//:incompatible"],
    "//conditions:default": [],
})

def _musl_alltypes_generation_test(arch):
    native.genrule(
        name = "musl_alltypes_{arch}_arch_old".format(arch = arch),
        testonly = True,
        srcs = [
            "@musl_libc//:arch/{arch}/bits/alltypes.h.in".format(arch = arch),
            "@musl_libc//:tools/mkalltypes.sed",
        ],
        outs = ["musl_header_generation/{arch}/old/alltypes_arch.h".format(arch = arch)],
        cmd = "sed -f $(location @musl_libc//:tools/mkalltypes.sed) $(location @musl_libc//:arch/{arch}/bits/alltypes.h.in) > $@".format(arch = arch),
        target_compatible_with = _SED_COMPATIBLE_WITH,
    )

    diff_test(
        name = "musl_alltypes_{arch}_arch_diff_test".format(arch = arch),
        failure_message = "Starlark alltypes arch generation drifted from musl's mkalltypes.sed for {arch}.".format(arch = arch),
        file1 = ":musl_alltypes_{arch}_arch_old".format(arch = arch),
        file2 = "@musl_libc//:alltypes_h_{arch}_arch".format(arch = arch),
        target_compatible_with = _SED_COMPATIBLE_WITH,
    )

    native.genrule(
        name = "musl_alltypes_{arch}_common_old".format(arch = arch),
        testonly = True,
        srcs = [
            "@musl_libc//:include/alltypes.h.in",
            "@musl_libc//:tools/mkalltypes.sed",
        ],
        outs = ["musl_header_generation/{arch}/old/alltypes_common.h".format(arch = arch)],
        cmd = "sed -f $(location @musl_libc//:tools/mkalltypes.sed) $(location @musl_libc//:include/alltypes.h.in) > $@",
        target_compatible_with = _SED_COMPATIBLE_WITH,
    )

    diff_test(
        name = "musl_alltypes_{arch}_common_diff_test".format(arch = arch),
        failure_message = "Starlark alltypes common generation drifted from musl's mkalltypes.sed for {arch}.".format(arch = arch),
        file1 = ":musl_alltypes_{arch}_common_old".format(arch = arch),
        file2 = "@musl_libc//:alltypes_h_{arch}_common".format(arch = arch),
        target_compatible_with = _SED_COMPATIBLE_WITH,
    )

def musl_header_generation_tests(name):
    for arch in _ARCHES:
        _musl_alltypes_generation_test(arch)

    native.test_suite(
        name = name,
        tests = [
            ":musl_alltypes_{arch}_arch_diff_test".format(arch = arch)
            for arch in _ARCHES
        ] + [
            ":musl_alltypes_{arch}_common_diff_test".format(arch = arch)
            for arch in _ARCHES
        ],
    )
