load("@bazel_features//:features.bzl", "bazel_features")
load("@llvm_config//:version.bzl", "LLVM_VERSION_MAJOR")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//platforms:common.bzl", "SUPPORTED_TARGETS")
load("//toolchain:cc_toolchain.bzl", "cc_toolchain")
load(":bootstrap_binary.bzl", "bootstrap_binary", "bootstrap_directory")

def _validate_static_library_tool(prefix):
    if not bazel_features.cc.supports_starlarkified_toolchains:
        return {}

    return {
        "@rules_cc//cc/toolchains/actions:validate_static_library": prefix + "/static-library-validator",
    }

def declare_tool_map(exec_os, exec_cpu):
    prefix = exec_os + "_" + exec_cpu

    native.platform(
        name = prefix + "_platform",
        constraint_values = [
            "@platforms//cpu:{}".format(exec_cpu),
            "@platforms//os:{}".format(exec_os),
        ],
    )

    BASE_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:c_compile": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:objc_compile": prefix + "/clang",
        "@llvm//toolchain:cpp_compile_actions_without_header_parsing": prefix + "/clang++",
        "@rules_cc//cc/toolchains/actions:dwp": prefix + "/llvm-dwp",
        "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": prefix + "/llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:strip": prefix + "/llvm-strip",
    }

    COMPLETE_ONLY_TOOLS = {
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": prefix + "/header-parser",
    } | _validate_static_library_tool(prefix)

    cc_tool_map(
        name = prefix + "/default_tools",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-ar",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_with_libtool",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-libtool-darwin",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_with_dsym",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/link-wrapper",
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-ar",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_with_dsym_and_libtool",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/link-wrapper",
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-libtool-darwin",
        },
    )

    cc_tool_map(
        name = prefix + "/staged_default_tools",
        tools = BASE_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-ar",
        },
    )

    cc_tool_map(
        name = prefix + "/staged_tools_with_libtool",
        tools = BASE_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-libtool-darwin",
        },
    )

    native.alias(
        name = prefix + "/default_tools_for_runtime",
        actual = select({
            "@llvm//toolchain:runtimes_all": prefix + "/default_tools",
            "//conditions:default": prefix + "/staged_default_tools",
        }),
    )

    native.alias(
        name = prefix + "/tools_with_libtool_for_runtime",
        actual = select({
            "@llvm//toolchain:runtimes_all": prefix + "/tools_with_libtool",
            "//conditions:default": prefix + "/staged_tools_with_libtool",
        }),
    )

    bootstrap_binary(
        name = prefix + "/bin/clang",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_directory(
        name = prefix + "/clang_builtin_headers_include_directory",
        srcs = "@llvm-project//clang:builtin_headers_files",
        # TODO(zbarsky): Probably shouldn't force platform here.
        platform = prefix + "_platform",
        destination = prefix + "/lib/clang/{}/include".format(LLVM_VERSION_MAJOR),
        strip_prefix = "clang/lib/Headers",
    )

    cc_tool(
        name = prefix + "/clang",
        src = prefix + "/bin/clang",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
    )

    bootstrap_binary(
        name = prefix + "/bin/clang++",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
        # Copy instead of symlink so clang's InstalledDir matches the packaged tree.
        # This is crucial for properly locating the various linkers, since we don't use `-ld-path`.
        symlink = False,
    )

    cc_tool(
        name = prefix + "/clang++",
        src = prefix + "/bin/clang++",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
    )

    cc_tool(
        name = prefix + "/header-parser",
        src = "@llvm//tools/internal:header-parser",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
            prefix + "/bin/clang++",
        ],
        env = {
            "LLVM_CLANGXX": "{clangxx}",
        },
        format = {
            "clangxx": prefix + "/bin/clang++",
        },
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-nm",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/c++filt",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/dsymutil",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/static-library-validator",
        src = "@llvm//tools/internal:static-library-validator",
        data = [
            prefix + "/bin/c++filt",
            prefix + "/bin/llvm-nm",
        ],
        env = {
            "LLVM_CXXFILT": "{cxxfilt}",
            "LLVM_NM": "{llvm_nm}",
        },
        format = {
            "cxxfilt": prefix + "/bin/c++filt",
            "llvm_nm": prefix + "/bin/llvm-nm",
        },
    )

    bootstrap_binary(
        name = prefix + "/bin/ld.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/ld64.lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/lld",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    bootstrap_binary(
        name = prefix + "/bin/wasm-ld",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/lld",
        src = prefix + "/bin/clang++",
        data = [
            prefix + "/bin/ld.lld",
            prefix + "/bin/ld64.lld",
            prefix + "/bin/lld",
            prefix + "/bin/wasm-ld",
        ],
    )

    cc_tool(
        name = prefix + "/link-wrapper",
        src = "@llvm//tools/internal:link-wrapper",
        data = [
            prefix + "/bin/clang++",
            prefix + "/bin/dsymutil",
            prefix + "/bin/llvm-strip",
            prefix + "/bin/ld.lld",
            prefix + "/bin/ld64.lld",
            prefix + "/bin/lld",
            prefix + "/bin/wasm-ld",
        ],
        env = {
            "LLVM_CLANGXX": "{clangxx}",
            "LLVM_DSYMUTIL": "{dsymutil}",
            "LLVM_STRIP": "{strip}",
        },
        format = {
            "clangxx": prefix + "/bin/clang++",
            "dsymutil": prefix + "/bin/dsymutil",
            "strip": prefix + "/bin/llvm-strip",
        },
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-ar",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-ar",
        src = prefix + "/bin/llvm-ar",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-libtool-darwin",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-libtool-darwin",
        src = prefix + "/bin/llvm-libtool-darwin",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-dwp",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-dwp",
        src = prefix + "/bin/llvm-dwp",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-objcopy",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-objcopy",
        src = prefix + "/bin/llvm-objcopy",
    )

    bootstrap_binary(
        name = prefix + "/bin/llvm-strip",
        platform = prefix + "_platform",
        actual = "@llvm-project//llvm:llvm.stripped",
    )

    cc_tool(
        name = prefix + "/llvm-strip",
        src = prefix + "/bin/llvm-strip",
        # TODO: Remove this once rules_cc includes validate_static_library in
        # all_files, or cc_static_library uses the validate action's files
        # directly. This hangs validator files off strip because strip is an
        # exec-configured tool already included in rules_cc 0.2.18's legacy
        # file groups.
        data = select({
            "@llvm//toolchain:runtimes_all": [
                "@llvm//tools/internal:static-library-validator",
            ],
            "//conditions:default": [],
        }) + [
            prefix + "/bin/c++filt",
            prefix + "/bin/llvm-nm",
        ],
    )

def declare_toolchains(*, execs = None, targets = SUPPORTED_TARGETS):
    """Declares the configured LLVM toolchains.

    Args:
        execs: List of (os, arch) tuples describing exec platforms.
        targets: List of (os, arch) tuples describing target platforms.
    """
    if not execs:
        execs = [
            (arch, os)
            # Any supported target that can run a compiler is a supported exec.
            # If we can compile a compiler for that target, we can use that compiler
            # to compile for any other target.
            for (arch, os) in targets
            if arch != "none"  # wasm is no good for us.
        ]

    for (exec_os, exec_cpu) in execs:
        declare_tool_map(exec_os, exec_cpu)

        cc_toolchain_name = "bootstrap_{}_{}_cc_toolchain".format(exec_os, exec_cpu)

        # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
        # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
        # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
        cc_toolchain(
            name = cc_toolchain_name,
            tool_map = select({
                "@llvm//toolchain:macos_complete_with_libtool": ":{}_{}/tools_with_dsym_and_libtool".format(exec_os, exec_cpu),
                "@llvm//toolchain:macos_complete": ":{}_{}/tools_with_dsym".format(exec_os, exec_cpu),
                "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_apple_setting": ":{}_{}/tools_with_libtool_for_runtime".format(exec_os, exec_cpu),
                "//conditions:default": ":{}_{}/default_tools_for_runtime".format(exec_os, exec_cpu),
            }),
        )

        for (target_os, target_cpu) in targets:
            native.toolchain(
                name = "bootstrap_{}_{}_to_{}_{}".format(exec_os, exec_cpu, target_os, target_cpu),
                exec_compatible_with = [
                    "@platforms//cpu:{}".format(exec_cpu),
                    "@platforms//os:{}".format(exec_os),
                ],
                target_compatible_with = [
                    "@platforms//cpu:{}".format(target_cpu),
                    "@platforms//os:{}".format(target_os),
                ],
                target_settings = [
                    "@llvm//toolchain:bootstrapped_toolchain",
                ],
                toolchain = cc_toolchain_name,
                toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                visibility = ["//visibility:public"],
            )
