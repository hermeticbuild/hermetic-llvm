load("//constraints/cxxstdlib:cxxstdlib_versions.bzl", "CXXSTDLIBS", "DEFAULT_CXXSTDLIB")
load("//constraints/libc:libc_versions.bzl", "LIBCS", "default_libc")
load("//platforms:common.bzl", "ARCH_ALIASES", "LIBC_SUPPORTED_TARGETS", "SUPPORTED_TARGETS")

def declare_platforms():
    for (target_os, target_cpu) in SUPPORTED_TARGETS:
        constraints = [
            "@platforms//cpu:{}".format(target_cpu),
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
            constraints.append("//constraints/libc:{}".format(default_libc(target_os, target_cpu)))

        native.platform(
            name = "{}_{}".format(target_os, target_cpu),
            constraint_values = constraints,
            visibility = ["//visibility:public"],
        )

        for alias in ARCH_ALIASES.get(target_cpu, []):
            native.platform(
                name = "{}_{}".format(target_os, alias),
                constraint_values = constraints,
                visibility = ["//visibility:public"],
            )

    declare_platforms_libc_aware()
    declare_platforms_cxxstdlib_aware()

def declare_platforms_libc_aware():
    for target_os, target_cpu in LIBC_SUPPORTED_TARGETS:
        for libc in LIBCS:
            native.platform(
                name = "{}_{}_{}".format(target_os, target_cpu, libc),
                constraint_values = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                    "//constraints/libc:{}".format(libc),
                    "//constraints/cxxstdlib:{}".format(DEFAULT_CXXSTDLIB),
                ],
                visibility = ["//visibility:public"],
            )

            for alias in ARCH_ALIASES.get(target_cpu, []):
                native.platform(
                    name = "{}_{}_{}".format(target_os, alias, libc),
                    constraint_values = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                        "//constraints/libc:{}".format(libc),
                        "//constraints/cxxstdlib:{}".format(DEFAULT_CXXSTDLIB),
                    ],
                    visibility = ["//visibility:public"],
                )

def declare_platforms_cxxstdlib_aware():
    for target_os, target_cpu in SUPPORTED_TARGETS:
        if target_os == "none":
            continue

        for cxxstdlib in CXXSTDLIBS:
            constraints = [
                "@platforms//cpu:{}".format(target_cpu),
                "@platforms//os:{}".format(target_os),
                "//constraints/cxxstdlib:{}".format(cxxstdlib),
            ]

            if target_os == "linux":
                constraints.append("//constraints/libc:{}".format(default_libc(target_os, target_cpu)))

            native.platform(
                name = "{}_{}_{}".format(target_os, target_cpu, cxxstdlib),
                constraint_values = constraints,
                visibility = ["//visibility:public"],
            )

            for alias in ARCH_ALIASES.get(target_cpu, []):
                native.platform(
                    name = "{}_{}_{}".format(target_os, alias, cxxstdlib),
                    constraint_values = constraints,
                    visibility = ["//visibility:public"],
                )

    for target_os, target_cpu in LIBC_SUPPORTED_TARGETS:
        for libc in LIBCS:
            for cxxstdlib in CXXSTDLIBS:
                native.platform(
                    name = "{}_{}_{}_{}".format(target_os, target_cpu, libc, cxxstdlib),
                    constraint_values = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                        "//constraints/libc:{}".format(libc),
                        "//constraints/cxxstdlib:{}".format(cxxstdlib),
                    ],
                    visibility = ["//visibility:public"],
                )

                for alias in ARCH_ALIASES.get(target_cpu, []):
                    native.platform(
                        name = "{}_{}_{}_{}".format(target_os, alias, libc, cxxstdlib),
                        constraint_values = [
                            "@platforms//cpu:{}".format(target_cpu),
                            "@platforms//os:{}".format(target_os),
                            "//constraints/libc:{}".format(libc),
                            "//constraints/cxxstdlib:{}".format(cxxstdlib),
                        ],
                        visibility = ["//visibility:public"],
                    )
