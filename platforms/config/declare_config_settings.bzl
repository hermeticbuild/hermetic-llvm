load("@bazel_skylib//lib:selects.bzl", "selects")
load("//constraints/libc:libc_versions.bzl", "GLIBCS", "LIBCS")
load("//constraints/windows/abi:abis.bzl", "WINDOWS_ABIS", "WINDOWS_MINGW_COMPATIBLE_ABIS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS", "SUPPORTED_TARGETS", "WINDOWS_TARGETS")
load("//toolchain:bootstrap_stages.bzl", "BOOTSTRAP_STAGES")
load(":libc.bzl", "target_libc")

def declare_config_settings():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:
        native.config_setting(
            name = "{}_{}".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:" + target_cpu,
                "@platforms//os:" + target_os,
            ],
            visibility = ["//visibility:public"],
        )

        for bootstrap_stage in BOOTSTRAP_STAGES:
            native.config_setting(
                name = "%s_%s_%s" % (target_os, target_cpu, bootstrap_stage),
                constraint_values = [
                    "@platforms//cpu:" + target_cpu,
                    "@platforms//os:" + target_os,
                ],
                flag_values = {
                    "//toolchain:bootstrap_stage": bootstrap_stage,
                },
                visibility = ["//visibility:public"],
            )

    declare_config_settings_libc_aware()
    declare_config_settings_windows_abi_aware()

def declare_config_settings_libc_aware():
    # See target_libc for how the libc that Linux targets compile against is chosen.
    target_libc(
        name = "target_libc",
    )
    target_libc(
        name = "target_libc_family",
        family = True,
    )

    native.config_setting(
        name = "musl",
        flag_values = {":target_libc_family": "musl"},
        visibility = ["//visibility:public"],
    )

    # Also matches if the target platform only makes unsupported glibc versions available, which
    # the per-version settings below don't.
    native.config_setting(
        name = "gnu",
        flag_values = {":target_libc_family": "gnu"},
        visibility = ["//visibility:public"],
    )

    for glibc in GLIBCS:
        native.config_setting(
            name = glibc,
            flag_values = {":target_libc": glibc},
            visibility = ["//visibility:public"],
        )

    for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS:
        constraint_values = [
            "@platforms//cpu:{}".format(target_cpu),
            "@platforms//os:{}".format(target_os),
        ]
        for libc in LIBCS:
            native.config_setting(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                constraint_values = constraint_values,
                flag_values = {":target_libc": libc},
                visibility = ["//visibility:public"],
            )

        native.config_setting(
            name = "{}_{}_gnu".format(target_os, target_cpu),
            constraint_values = constraint_values,
            flag_values = {":target_libc_family": "gnu"},
            visibility = ["//visibility:public"],
        )

        # Matches platforms without a //constraints/libc value, whatever libc they compile against.
        native.config_setting(
            name = "{}_{}_unconstrained".format(target_os, target_cpu),
            constraint_values = constraint_values + ["//constraints/libc:unconstrained"],
            visibility = ["//visibility:public"],
        )

def declare_config_settings_windows_abi_aware():
    for target_os, target_cpu in WINDOWS_TARGETS:
        for abi in WINDOWS_ABIS:
            native.config_setting(
                name = "{}_{}_{}".format(target_os, target_cpu, abi),
                constraint_values = [
                    "@platforms//cpu:" + target_cpu,
                    "@platforms//os:" + target_os,
                    "//constraints/windows/abi:" + abi,
                ],
                visibility = ["//visibility:public"],
            )

        selects.config_setting_group(
            name = "{}_{}_mingw_compatible".format(target_os, target_cpu),
            match_any = [
                "{}_{}_{}".format(target_os, target_cpu, abi)
                for abi in WINDOWS_MINGW_COMPATIBLE_ABIS
            ],
            visibility = ["//visibility:public"],
        )
