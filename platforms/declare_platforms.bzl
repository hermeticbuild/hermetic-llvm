load("@bazel_features//:features.bzl", "bazel_features")
load("@platforms_contrib//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("@platforms_contrib//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
load("//constraints/cxxstdlib:cxxstdlib_versions.bzl", "DEFAULT_CXXSTDLIB")
load("//constraints/libc:libc_versions.bzl", "LIBCS", "MUSL_VERSION", "default_libc")
load("//constraints/windows/abi:abis.bzl", "WINDOWS_GENERIC_PLATFORM_ABI")
load("//platforms:common.bzl", "ARCH_ALIASES", "LIBC_SUPPORTED_TARGETS", "SUPPORTED_TARGETS")
load("//toolchain/args:x86_64_cpu.bzl", "MACOS_X86_64_FEATURES")

def _libc_constraints(libc):
    """Returns the constraints of a platform that compiles against the given libc.

    The //constraints/libc value keeps select()s on it working, the @platforms_contrib constraints
    describe the libc available on the platform to other toolchains.
    """
    if libc == "musl":
        available = musl_version_constraints(MUSL_VERSION)
    else:
        available = glibc_version_constraints(libc.removeprefix("gnu."))
    return ["//constraints/libc:{}".format(libc)] + available

def _cpu_constraints(target_os, target_cpu):
    constraints = ["@platforms//cpu:{}".format(target_cpu)]
    if (target_os, target_cpu) == ("macos", "x86_64"):
        constraints += [
            "@platforms_contrib//cpu/x86_64/feature:{}_available".format(feature)
            for feature in MACOS_X86_64_FEATURES
        ]
    return constraints

def _platform(name, target_cpu, **kwargs):
    # A transition from e.g. @platforms_contrib//host:native would otherwise keep its CPU model.
    if target_cpu == "x86_64" and bazel_features.rules.platform_has_flags:
        kwargs["flags"] = ["--{}=".format(Label("@platforms_contrib//cpu/x86_64:model"))]
    native.platform(
        name = name,
        visibility = ["//visibility:public"],
        **kwargs
    )

def declare_platforms():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:
        constraints = _cpu_constraints(target_os, target_cpu) + [
            "@platforms//os:{}".format(target_os),
        ]

        if target_os != "none":
            constraints.append("//constraints/cxxstdlib:{}".format(DEFAULT_CXXSTDLIB))

        if target_os == "linux":
            # We add a default glibc constraint for linux platforms.
            #
            # This is needed because some toolchains require a libc constraint
            # to be present on the platform in order to select the right
            # toolchain implementation.
            #
            # Users can still create their own platforms without a libc
            # constraint if they want to.
            constraints.extend(_libc_constraints(default_libc(target_os, target_cpu)))

        if target_os == "windows":
            # Repository-owned Windows platforms state their existing GNU ABI
            # contract explicitly. The constraint default remains
            # unconstrained for downstream platforms that do not know about
            # this toolchain-specific dimension.
            constraints.append("//constraints/windows/abi:" + WINDOWS_GENERIC_PLATFORM_ABI)

        _platform(
            name = "{}_{}".format(target_os, target_cpu),
            target_cpu = target_cpu,
            constraint_values = constraints,
        )

        for alias in ARCH_ALIASES.get(target_cpu, []):
            _platform(
                name = "{}_{}".format(target_os, alias),
                target_cpu = target_cpu,
                constraint_values = constraints,
            )

    declare_platforms_libc_aware()
    declare_windows_msvc_platforms()

def declare_windows_msvc_platforms():
    for target_cpu in ["x86_64", "aarch64"]:
        _platform(
            name = "windows_{}_msvc".format(target_cpu),
            target_cpu = target_cpu,
            constraint_values = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:windows",
                "//constraints/cxxstdlib:libcxx",
                "//constraints/windows/abi:msvc",
                "//constraints/windows/crt:ucrt",
            ],
        )

def declare_platforms_libc_aware():
    for target_os, target_cpu in LIBC_SUPPORTED_TARGETS:
        for libc in LIBCS:
            constraints = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:{}".format(target_os),
                "//constraints/cxxstdlib:{}".format(DEFAULT_CXXSTDLIB),
            ] + _libc_constraints(libc)

            _platform(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                target_cpu = target_cpu,
                constraint_values = constraints,
            )

            for alias in ARCH_ALIASES.get(target_cpu, []):
                _platform(
                    name = "{}_{}_{}".format(target_os, alias, libc),
                    target_cpu = target_cpu,
                    constraint_values = constraints,
                )
