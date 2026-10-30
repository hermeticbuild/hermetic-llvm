"""Analysis-time validation for the frozen MSVC ABI configuration matrix."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")

def _has_constraint(ctx, target):
    return ctx.target_platform_has_constraint(
        target[platform_common.ConstraintValueInfo],
    )

def validate_msvc_configuration(
        *,
        is_msvc_abi,
        is_legacy_msvcrt,
        is_libcxx,
        enabled_features,
        disabled_features,
        unsupported_features,
        enabled_build_settings = []):
    # type: (bool, bool, bool, Collection[str], Collection[str], Collection[str], Collection[str]) -> str | None
    """Validates the frozen Layer 1 MSVC configuration.

    Returns:
        The configuration error string, or None when valid.
    """
    if not is_msvc_abi:
        return None
    if is_legacy_msvcrt:
        return "MSVC ABI requires //constraints/windows/crt:ucrt; legacy msvcrt is MinGW-only"
    if not is_libcxx:
        return "Layer 1 MSVC ABI requires //constraints/cxxstdlib:libcxx"

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
    # type: (...) -> list[DefaultInfo]
    error = validate_msvc_configuration(
        is_legacy_msvcrt = _has_constraint(ctx, ctx.attr._legacy_msvcrt),
        is_libcxx = _has_constraint(ctx, ctx.attr._libcxx),
        is_msvc_abi = _has_constraint(ctx, ctx.attr._msvc_abi),
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
    },
)
