"""Analysis-time validation for the frozen MSVC ABI configuration matrix."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _has_constraint(ctx, attr_name):
    return ctx.target_platform_has_constraint(
        getattr(ctx.attr, attr_name)[platform_common.ConstraintValueInfo],
    )

def validate_msvc_configuration(
        *,
        is_msvc_abi,
        is_legacy_msvcrt,
        is_libcxx,
        enabled_features,
        disabled_features,
        unsupported_features,
        is_msvcstl = False,
        enabled_build_settings = []):
    """Validates the frozen Layer 1 MSVC configuration.

    Returns:
        The configuration error string, or None when valid.
    """
    if not is_msvc_abi:
        return None
    if is_legacy_msvcrt:
        return "MSVC ABI requires //constraints/windows/crt:ucrt; legacy msvcrt is MinGW-only"
    if not (is_libcxx or is_msvcstl):
        return "MSVC ABI requires //constraints/cxxstdlib:libcxx or //constraints/cxxstdlib:msvcstl"

    enabled = {feature: True for feature in enabled_features}
    disabled = {feature: True for feature in disabled_features}
    if "dynamic_link_msvcrt" in disabled and "static_link_msvcrt" not in enabled:
        return "MSVC ABI requires exactly one retail CRT mode: enable dynamic_link_msvcrt or static_link_msvcrt"

    for setting in enabled_build_settings:
        enabled[setting] = True
    unsupported = sorted([feature for feature in enabled if feature in unsupported_features])
    if unsupported:
        return "MSVC ABI Layer 1 does not support feature(s): {}".format(", ".join(unsupported))
    return None

def _msvc_configuration_validation_impl(ctx):
    is_msvc_abi = _has_constraint(ctx, "_msvc_abi")
    is_msvcstl = _has_constraint(ctx, "_msvcstl")
    if is_msvcstl and not (is_msvc_abi and _has_constraint(ctx, "_windows")):
        fail("//constraints/cxxstdlib:msvcstl requires a Windows MSVC target")

    error = validate_msvc_configuration(
        is_legacy_msvcrt = _has_constraint(ctx, "_legacy_msvcrt"),
        is_libcxx = _has_constraint(ctx, "_libcxx"),
        is_msvc_abi = is_msvc_abi,
        is_msvcstl = is_msvcstl,
        enabled_features = ctx.features,
        disabled_features = ctx.disabled_features,
        enabled_build_settings = [
            setting.label.name
            for setting in ctx.attr.unsupported_build_settings
            if setting[BuildSettingInfo].value
        ],
        unsupported_features = ctx.attr.unsupported_features,
    )
    if error:
        fail(error)

    return [DefaultInfo()]

msvc_configuration_validation = rule(
    implementation = _msvc_configuration_validation_impl,
    attrs = {
        "unsupported_build_settings": attr.label_list(providers = [BuildSettingInfo]),
        "unsupported_features": attr.string_list(),
        "_libcxx": attr.label(default = "//constraints/cxxstdlib:libcxx"),
        "_legacy_msvcrt": attr.label(default = "//constraints/windows/crt:msvcrt"),
        "_msvc_abi": attr.label(default = "//constraints/windows/abi:msvc"),
        "_msvcstl": attr.label(default = "//constraints/cxxstdlib:msvcstl"),
        "_windows": attr.label(default = "@platforms//os:windows"),
    },
)
