load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//constraints/libc:libc_versions.bzl", "DEFAULT_LIBC", "GLIBC_VERSIONS", "LIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

_GLIBC = "@platforms_contrib//os/linux/libc/glibc:"
_MUSL = "@platforms_contrib//os/linux/libc/musl:"

# The libcs that //config/linux:libc_preference can rank.
_LINUX_LIBCS = ["glibc", "musl"]

# The value for platforms that only make glibc versions older than the supported ones available.
UNSUPPORTED_GLIBC = "gnu.unsupported"

def _has(ctx, constraint_value):
    return ctx.target_platform_has_constraint(constraint_value[platform_common.ConstraintValueInfo])

def _choose_libc(ctx, libcs):
    """Returns the target_libc value of the libc that //config/linux:libc_preference chooses.

    Args:
      ctx: The rule context.
      libcs: The target_libc value of each libc in _LINUX_LIBCS, or None if it isn't available.
        UNSUPPORTED_GLIBC is only chosen if no other listed libc is available.
    """
    available = [libc for libc in _LINUX_LIBCS if libcs[libc]]
    preference_flag = ctx.attr._libc_preference
    preference = preference_flag[BuildSettingInfo].value
    for libc in preference:
        if libc not in _LINUX_LIBCS:
            fail("--{}: unknown libc '{}', expected one of: {}".format(
                preference_flag.label,
                libc,
                ", ".join(_LINUX_LIBCS),
            ))

    ranked = [libcs[libc] for libc in preference if libc in available]
    for libc in ranked:
        if libc != UNSUPPORTED_GLIBC:
            return libc
    if ranked:
        return ranked[0]
    fail("--{}={} doesn't list any libc that the target platform makes available: {}".format(
        preference_flag.label,
        ",".join(preference),
        ", ".join(available),
    ))

def _target_libc(ctx):
    if not _has(ctx, ctx.attr._linux) or not any([_has(ctx, cpu) for cpu in ctx.attr._cpus]):
        return "none"

    for legacy_libc in ctx.attr._legacy_libcs:
        if _has(ctx, legacy_libc):
            return legacy_libc.label.name

    glibc = None
    if _has(ctx, ctx.attr._glibc_available):
        glibc = UNSUPPORTED_GLIBC
        for version, at_least in reversed(zip(GLIBC_VERSIONS, ctx.attr._glibc_at_least)):
            if _has(ctx, at_least):
                glibc = "gnu." + version
                break
    libcs = {"glibc": glibc, "musl": "musl" if _has(ctx, ctx.attr._musl_available) else None}

    # Platforms without libc constraints don't restrict the libc.
    if not any(libcs.values()):
        libcs = {"glibc": DEFAULT_LIBC, "musl": "musl"}
    return _choose_libc(ctx, libcs)

def _target_libc_impl(ctx):
    libc = _target_libc(ctx)
    if ctx.attr.family:
        libc = libc.partition(".")[0]
    return [config_common.FeatureFlagInfo(value = libc)]

target_libc = rule(
    implementation = _target_libc_impl,
    doc = """Provides the libc that Linux targets compile against for config_setting.flag_values.

A //constraints/libc value on the target platform takes precedence. Otherwise, the libc is one of
those that the @platforms_contrib//os/linux/libc constraints of the platform make available, or any
if it has no such constraints: the first one listed in //config/linux:libc_preference. For glibc,
it's the newest supported version that the platform makes available, or DEFAULT_LIBC if it has no
libc constraints.
""",
    attrs = {
        "family": attr.bool(doc = "Whether to omit the glibc version."),
        "_cpus": attr.label_list(default = [
            "@platforms//cpu:" + target_cpu
            for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS
            if target_os == "linux"
        ]),
        "_glibc_at_least": attr.label_list(default = [
            _GLIBC + "at_least_{}_available".format(version)
            for version in GLIBC_VERSIONS
        ]),
        "_glibc_available": attr.label(default = _GLIBC + "available"),
        "_legacy_libcs": attr.label_list(default = ["//constraints/libc:" + libc for libc in LIBCS]),
        "_libc_preference": attr.label(default = "//config/linux:libc_preference"),
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_musl_available": attr.label(default = _MUSL + "available"),
    },
)
