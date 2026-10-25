load("@platforms_contrib//os/linux/libc/glibc:glibc.bzl", "glibc_version_constraints")
load("@platforms_contrib//os/linux/libc/musl:musl.bzl", "musl_version_constraints")
load("@rules_testing//lib:analysis_test.bzl", "analysis_test")
load("@rules_testing//lib:truth.bzl", "matching")
load("//constraints/libc:libc_versions.bzl", "LIBCS")
load("//platforms/config:libc.bzl", "target_libc")

_LibcInfo = provider(
    doc = "The values that the libc config settings select.",
    fields = ["libc", "family", "linux_x86_64_libc", "most_specific"],
)

def _libc_impl(ctx):
    return [_LibcInfo(
        libc = ctx.attr.libc,
        family = ctx.attr.family,
        linux_x86_64_libc = ctx.attr.linux_x86_64_libc,
        most_specific = ctx.attr.most_specific,
    )]

_libc = rule(
    implementation = _libc_impl,
    attrs = {
        "family": attr.string(),
        "libc": attr.string(),
        "linux_x86_64_libc": attr.string(),
        "most_specific": attr.string(),
    },
)

def _expect_libc(libc, family):
    def impl(env, target):
        info = target[_LibcInfo]
        env.expect.that_str(info.libc).equals(libc)
        env.expect.that_str(info.family).equals(family)
        env.expect.that_str(info.linux_x86_64_libc).equals(libc)
        env.expect.that_str(info.most_specific).equals(
            "linux_x86_64_" + libc if libc in ("gnu.2.31", "musl") else family,
        )

    return impl

def _expect_failure(message):
    def impl(env, target):
        env.expect.that_target(target).failures().contains_predicate(matching.contains(message))

    return impl

_PREFERENCE = str(Label("//config/linux:libc_preference"))

_X86_64_LINUX = ["@platforms//cpu:x86_64", "@platforms//os:linux"]

def _platform(name, platform):
    """Returns the label of a platform declared by libc_test_suite or the given label."""
    return platform if platform.startswith("//") else ":{}_{}".format(name, platform)

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
        # Settings that imply others specialize them.
        most_specific = select({
            "//platforms/config:gnu": "gnu",
            "//platforms/config:gnu.2.31": "gnu.2.31",
            "//platforms/config:linux_x86_64_gnu.2.31": "linux_x86_64_gnu.2.31",
            "//platforms/config:musl": "musl",
            "//platforms/config:linux_x86_64_musl": "linux_x86_64_musl",
            "//conditions:default": "none",
        }),
    )

    platforms = {
        "no_libc": [],
        "glibc_2.31": glibc_version_constraints("2.31"),
        "glibc_2.45": glibc_version_constraints("2.45"),
        "glibc_2.17": glibc_version_constraints("2.17"),
        "glibc_2.17_and_musl": glibc_version_constraints("2.17") + musl_version_constraints("1.2"),
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

    for test, platform, settings, libc in [
        # Without libc constraints, every libc is available, glibc at the default version.
        ("no_libc", "no_libc", {}, "gnu.2.28"),
        ("no_libc_prefer_musl", "no_libc", {_PREFERENCE: ["musl", "glibc"]}, "musl"),
        ("glibc", "glibc_2.31", {}, "gnu.2.31"),
        # The ranking only matters if more than one libc is available.
        ("glibc_prefer_musl", "glibc_2.31", {_PREFERENCE: ["musl", "glibc"]}, "gnu.2.31"),
        ("newer_glibc", "glibc_2.45", {}, "gnu.2.44"),
        ("older_glibc", "glibc_2.17", {}, "none"),
        # Unsupported glibc versions are only chosen if no other listed libc is available.
        ("older_glibc_and_musl", "glibc_2.17_and_musl", {}, "musl"),
        ("older_glibc_and_musl_only_glibc", "glibc_2.17_and_musl", {_PREFERENCE: ["glibc"]}, "none"),
        ("musl", "musl", {}, "musl"),
        ("glibc_and_musl", "glibc_2.35_and_musl", {}, "gnu.2.35"),
        ("glibc_and_musl_prefer_musl", "glibc_2.35_and_musl", {_PREFERENCE: ["musl", "glibc"]}, "musl"),
        ("glibc_and_musl_only_musl", "glibc_2.35_and_musl", {_PREFERENCE: ["musl"]}, "musl"),
        # A //constraints/libc value takes precedence.
        ("legacy_gnu", "legacy_gnu_2.31_and_musl", {_PREFERENCE: ["musl"]}, "gnu.2.31"),
        ("legacy_musl", "legacy_musl_and_glibc_2.35", {}, "musl"),
        ("repo_platform", "//platforms:linux_x86_64_gnu.2.39", {}, "gnu.2.39"),
        ("repo_musl_platform", "//platforms:linux_x86_64_musl", {}, "musl"),
        # The ranking only applies to Linux.
        ("macos", "//platforms:macos_aarch64", {_PREFERENCE: ["bionic"]}, "none"),
    ]:
        # Unsupported glibc versions match no version, which fails select()s without a default.
        family = "gnu" if test.startswith("older_glibc") and libc == "none" else libc.partition(".")[0]
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_subject".format(name),
            impl = _expect_libc(libc, family),
            config_settings = {
                "//command_line_option:platforms": str(Label(_platform(name, platform))),
            } | settings,
        )

    target_libc(
        name = name + "_target_libc",
        tags = ["manual"],
    )

    for test, platform, settings, message in [
        (
            "unlisted_libc",
            "glibc_2.31",
            {_PREFERENCE: ["musl"]},
            "doesn't list any libc that the target platform makes available: glibc",
        ),
        (
            "empty_ranking",
            "no_libc",
            {_PREFERENCE: []},
            "doesn't list any libc that the target platform makes available: glibc, musl",
        ),
        (
            "unknown_libc",
            "glibc_2.35_and_musl",
            {_PREFERENCE: ["bionic", "glibc"]},
            "unknown libc 'bionic', expected one of: glibc, musl",
        ),
    ]:
        analysis_test(
            name = "{}_{}_test".format(name, test),
            target = ":{}_target_libc".format(name),
            impl = _expect_failure(message),
            expect_failure = True,
            config_settings = {
                "//command_line_option:platforms": str(Label(_platform(name, platform))),
            } | settings,
        )
