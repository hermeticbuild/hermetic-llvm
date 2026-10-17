load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("//constraints/libc:libc_versions.bzl", "DEFAULT_LIBC", "GLIBC_VERSIONS", "LIBCS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS")

_GLIBC = "@platforms_contrib//os/linux/libc/glibc:"
_MUSL = "@platforms_contrib//os/linux/libc/musl:"

# The value for platforms that only make glibc versions older than the supported ones available.
UNSUPPORTED_GLIBC = "gnu.unsupported"

def _has(ctx, constraint_value):
    return ctx.target_platform_has_constraint(constraint_value[platform_common.ConstraintValueInfo])

def _target_libc(ctx):
    if not _has(ctx, ctx.attr._linux) or not any([_has(ctx, cpu) for cpu in ctx.attr._cpus]):
        return "none"

    for legacy_libc in ctx.attr._legacy_libcs:
        if _has(ctx, legacy_libc):
            return legacy_libc.label.name

    glibc_available = _has(ctx, ctx.attr._glibc_available)
    if _has(ctx, ctx.attr._musl_available):
        if not glibc_available or ctx.attr._preferred_libc[BuildSettingInfo].value == "musl":
            return "musl"
    if not glibc_available:
        return DEFAULT_LIBC

    for version, at_least in reversed(zip(GLIBC_VERSIONS, ctx.attr._glibc_at_least)):
        if _has(ctx, at_least):
            return "gnu." + version
    return UNSUPPORTED_GLIBC

def _target_libc_impl(ctx):
    libc = _target_libc(ctx)
    if ctx.attr.family:
        libc = libc.partition(".")[0]
    return [config_common.FeatureFlagInfo(value = libc)]

target_libc = rule(
    implementation = _target_libc_impl,
    doc = """Provides the libc that Linux targets compile against for config_setting.flag_values.

A //constraints/libc value on the target platform takes precedence. Otherwise, the libc follows
from the @platforms_contrib//os/linux/libc constraints of the platform: it's the one that the
platform makes available, //config:preferred_libc if it makes both available and DEFAULT_LIBC if it
makes none available. For glibc, it's the newest supported version that the platform makes
available.
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
        "_linux": attr.label(default = "@platforms//os:linux"),
        "_musl_available": attr.label(default = _MUSL + "available"),
        "_preferred_libc": attr.label(default = "//config:preferred_libc"),
    },
)
