load("@bazel_skylib//lib:selects.bzl", "selects")
load("//constraints/libc:libc_versions.bzl", "GLIBCS", "LIBCS")
load("//constraints/windows/abi:abis.bzl", "WINDOWS_ABIS")
load("//platforms:common.bzl", "LIBC_SUPPORTED_TARGETS", "SUPPORTED_TARGETS", "WINDOWS_ABI_SUPPORTED_TARGETS")

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

        native.config_setting(
            name = "{}_{}_prebuilt".format(target_os, target_cpu),
            constraint_values = [
                "@platforms//cpu:" + target_cpu,
                "@platforms//os:" + target_os,
            ],
            flag_values = {
                "//toolchain:source": "prebuilt",
            },
            visibility = ["//visibility:public"],
        )

    declare_config_settings_libc_aware()
    declare_config_settings_windows_abi_aware()

def declare_config_settings_libc_aware():
    for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS:
        for libc in LIBCS + ["unconstrained"]:
            native.config_setting(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/libc:{}".format(libc),
                ],
                visibility = ["//visibility:public"],
            )

        selects.config_setting_group(
            name = "{}_{}_gnu".format(target_os, target_cpu),
            match_all = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:{}".format(target_os),
                ":gnu",
            ],
            visibility = ["//visibility:public"],
        )

    selects.config_setting_group(
        name = "gnu",
        match_any = [
            "//constraints/libc:{}".format(libc)
            for libc in GLIBCS
        ] + [
            "{}_{}_unconstrained".format(target_os, target_cpu)
            for (target_os, target_cpu) in LIBC_SUPPORTED_TARGETS
        ],
        visibility = ["//visibility:public"],
    )

    native.config_setting(
        name = "musl",
        constraint_values = [
            "//constraints/libc:musl",
        ],
        visibility = ["//visibility:public"],
    )

def declare_config_settings_windows_abi_aware():
    for abi in WINDOWS_ABIS:
        for (target_os, target_cpu) in WINDOWS_ABI_SUPPORTED_TARGETS:
            native.config_setting(
                name = "{}_{}_{}".format(target_os, target_cpu, abi),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/windows/abi:{}".format(abi),
                ],
                visibility = ["//visibility:public"],
            )
