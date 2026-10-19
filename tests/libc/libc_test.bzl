load("@platforms_contrib//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("@platforms_contrib//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("//constraints/libc:libc_versions.bzl", "LIBCS")

_LibcInfo = provider(
    doc = "The values that the libc config settings select.",
    fields = ["libc", "family", "linux_x86_64_libc"],
)

def _libc_impl(ctx):
    return [_LibcInfo(
        libc = ctx.attr.libc,
        family = ctx.attr.family,
        linux_x86_64_libc = ctx.attr.linux_x86_64_libc,
    )]

_libc = rule(
    implementation = _libc_impl,
    attrs = {
        "family": attr.string(),
        "libc": attr.string(),
        "linux_x86_64_libc": attr.string(),
    },
)

def _expect_libc(libc, family):
    def impl(env, target):
        info = target[_LibcInfo]
        env.expect.that_str(info.libc).equals(libc)
        env.expect.that_str(info.family).equals(family)
        env.expect.that_str(info.linux_x86_64_libc).equals(libc)

    return impl

_X86_64_LINUX = ["@platforms//cpu:x86_64", "@platforms//os:linux"]

def libc_test_suite(name):
    _libc(
        name = name + "_subject",
        libc = select({
            "//platforms/config:" + libc: libc
            for libc in LIBCS
        } | {"//conditions:default": "none"}),
        family = select({
            "//platforms/config:gnu": "gnu",
            "//platforms/config:musl": "musl",
            "//conditions:default": "none",
        }),
        linux_x86_64_libc = select({
            "//platforms/config:linux_x86_64_" + libc: libc
            for libc in LIBCS
        } | {"//conditions:default": "none"}),
    )

    platforms = {
        "no_libc": [],
        "glibc_2.31": glibc_version_constraints("2.31"),
        "glibc_2.45": glibc_version_constraints("2.45"),
        "glibc_2.17": glibc_version_constraints("2.17"),
        "musl": musl_version_constraints("1.2"),
        "glibc_2.35_and_musl": glibc_version_constraints("2.35") + musl_version_constraints("1.2"),
        "legacy_gnu_2.31_and_musl": ["//constraints/libc:gnu.2.31"] + musl_version_constraints("1.2"),
        "legacy_musl_and_glibc_2.35": ["//constraints/libc:musl"] + glibc_version_constraints("2.35"),
    }
    for platform, constraints in platforms.items():
        native.platform(
            name = "{}_{}".format(name, platform),
            constraint_values = _X86_64_LINUX + constraints,
        )

    for test, platform, preferred_libc, libc in [
        # The default glibc version applies without libc constraints.
        ("no_libc", ":{}_no_libc".format(name), "glibc", "gnu.2.28"),
        ("no_libc_prefer_musl", ":{}_no_libc".format(name), "musl", "gnu.2.28"),
        ("glibc", ":{}_glibc_2.31".format(name), "glibc", "gnu.2.31"),
        # The preference only matters if both are available.
        ("glibc_prefer_musl", ":{}_glibc_2.31".format(name), "musl", "gnu.2.31"),
        ("newer_glibc", ":{}_glibc_2.45".format(name), "glibc", "gnu.2.44"),
        ("older_glibc", ":{}_glibc_2.17".format(name), "glibc", "none"),
        ("musl", ":{}_musl".format(name), "glibc", "musl"),
        ("glibc_and_musl", ":{}_glibc_2.35_and_musl".format(name), "glibc", "gnu.2.35"),
        ("glibc_and_musl_prefer_musl", ":{}_glibc_2.35_and_musl".format(name), "musl", "musl"),
        # A //constraints/libc value takes precedence.
        ("legacy_gnu", ":{}_legacy_gnu_2.31_and_musl".format(name), "musl", "gnu.2.31"),
        ("legacy_musl", ":{}_legacy_musl_and_glibc_2.35".format(name), "glibc", "musl"),
        ("repo_platform", "//platforms:linux_x86_64_gnu.2.39", "glibc", "gnu.2.39"),
        ("repo_musl_platform", "//platforms:linux_x86_64_musl", "glibc", "musl"),
        ("macos", "//platforms:macos_aarch64", "glibc", "none"),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            # Unsupported glibc versions match no version, which fails select()s without a default.
            impl = _expect_libc(libc, family = "gnu" if test == "older_glibc" else libc.partition(".")[0]),
            config_settings = {
                "//command_line_option:platforms": str(Label(platform)),
                str(Label("//config:preferred_libc")): preferred_libc,
            },
        )
