load("@bazel_lib//lib:transitions.bzl", "platform_transition_binary")
load("@llvm//:defs.bzl", "exec_test")
load("@rules_rs//rs:rust_binary.bzl", "rust_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")

def rust_binary_test_suite(name, check, platform = None, **kwargs):
    binary_name = name + "_binary"

    rust_binary(
        name = binary_name + "_raw",
        **kwargs
    )

    platform_transition_binary(
        name = binary_name,
        target_platform = platform,
        binary = binary_name + "_raw",
    )

    # Test if the host binary works.
    exec_test(
        rule = sh_test,
        name = name,
        srcs = ["test_platform.sh"] if platform else ["test_hello_world.sh"],
        args = [
            "$(rootpath :" + binary_name + ")",
            check,
        ] if platform else [
            "$(rlocationpath :" + binary_name + ")",
        ],
        env = {
            "FILE_BINARY": "$(rootpath @libmagic//:file)",
            "MAGIC_FILE": "$(rootpath @libmagic//:magic.mgc)",
        } if platform else {},
        tools = ([
            "@libmagic//:file",
            "@libmagic//:magic.mgc",
        ] if platform else []),
        data = [binary_name],
        deps = [
            "@bazel_tools//tools/bash/runfiles",
        ],
    )

def rust_binary_cross_build_test_suite(name, platforms, **kwargs):
    rust_binary(
        name = name,
        **kwargs
    )

    for (platform, check) in platforms.items():
        for use_cc_common_link in [0, 1]:
            rust_binary_test_suite(
                name = "test_" + name + "_" + platform.split(":")[-1] + (
                    "_cc_common_link" if use_cc_common_link else ""
                ),
                check = check,
                platform = platform,
                experimental_use_cc_common_link = use_cc_common_link,
                **kwargs
            )
