load("@bazel_features//:features.bzl", "bazel_features")
load("@llvm_config//:version.bzl", "LLVM_VERSION_MAJOR")
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
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

def _exec_prefix(exec_os, exec_cpu):
    return exec_os + "_" + exec_cpu

def _exec_platform_name(exec_os, exec_cpu):
    return _exec_prefix(exec_os, exec_cpu) + "_platform"

def _declare_exec_platform(exec_os, exec_cpu):
    native.platform(
        name = _exec_platform_name(exec_os, exec_cpu),
        constraint_values = [
            "@platforms//cpu:{}".format(exec_cpu),
            "@platforms//os:{}".format(exec_os),
        ],
    )

def _bootstrap_tool_binary(name, platform, actual, fdo_profile = None, profile_instrumented = False, symlink = True):
    kwargs = {}
    if fdo_profile:
        kwargs["fdo_profile"] = fdo_profile
    if profile_instrumented:
        kwargs["profile_instrumented"] = True
    if not symlink:
        kwargs["symlink"] = False

    bootstrap_binary(
        name = name,
        platform = platform,
        actual = actual,
        visibility = ["//visibility:public"],
        **kwargs
    )

def declare_tool_map(exec_os, exec_cpu, prefix = None, fdo_profile = None, profile_instrumented = False):
    if not prefix:
        prefix = _exec_prefix(exec_os, exec_cpu)

    platform_name = _exec_platform_name(exec_os, exec_cpu)
    bootstrap_tool_kwargs = {
        "platform": platform_name,
        "fdo_profile": fdo_profile,
        "profile_instrumented": profile_instrumented,
    }

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:c_compile": prefix + "/clang",
        "@rules_cc//cc/toolchains/actions:objc_compile": prefix + "/clang",
        "@llvm//toolchain:cpp_compile_actions_without_header_parsing": prefix + "/clang++",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": prefix + "/header-parser",
        "@rules_cc//cc/toolchains/actions:dwp": prefix + "/llvm-dwp",
        "@rules_cc//cc/toolchains/actions:link_actions": prefix + "/lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": prefix + "/llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:strip": prefix + "/llvm-strip",
    } | _validate_static_library_tool(prefix)

    cc_tool_map(
        name = prefix + "/default_tools",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-ar",
        },
    )

    cc_tool_map(
        name = prefix + "/tools_with_libtool",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": prefix + "/llvm-libtool-darwin",
        },
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/clang",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    bootstrap_directory(
        name = prefix + "/clang_builtin_headers_include_directory",
        srcs = "@llvm-project//clang:builtin_headers_files",
        # TODO(zbarsky): Probably shouldn't force platform here.
        platform = platform_name,
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

    _bootstrap_tool_binary(
        name = prefix + "/bin/clang++",
        actual = "@llvm-project//llvm:llvm.stripped",
        # Copy instead of symlink so clang's InstalledDir matches the packaged tree.
        # This is crucial for properly locating the various linkers, since we don't use `-ld-path`.
        symlink = False,
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/clang++",
        src = prefix + "/bin/clang++",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/header-parser",
        actual = "@llvm//tools/internal:header-parser",
        **bootstrap_tool_kwargs
    )

    cc_args(
        name = prefix + "/header-parser-args",
        actions = [
            "@rules_cc//cc/toolchains/actions:cpp_header_parsing",
        ],
        data = [
            prefix + "/bin/clang++",
        ],
        env = {
            "LLVM_CLANGXX": "{clangxx}",
        },
        format = {
            "clangxx": prefix + "/bin/clang++",
        },
    )

    cc_tool(
        name = prefix + "/header-parser",
        src = prefix + "/bin/header-parser",
        data = [
            prefix + "/clang_builtin_headers_include_directory",
            prefix + "/bin/clang++",
        ],
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/static-library-validator",
        actual = "@llvm//tools/internal:static-library-validator",
        **bootstrap_tool_kwargs
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-nm",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/c++filt",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_args(
        name = prefix + "/static-library-validator-args",
        actions = [
            "@rules_cc//cc/toolchains/actions:validate_static_library",
        ],
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

    cc_tool(
        name = prefix + "/static-library-validator",
        src = prefix + "/bin/static-library-validator",
        data = [
            prefix + "/bin/c++filt",
            prefix + "/bin/llvm-nm",
        ],
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/ld.lld",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/ld64.lld",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/lld",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/wasm-ld",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
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

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-ar",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/llvm-ar",
        src = prefix + "/bin/llvm-ar",
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-libtool-darwin",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/llvm-libtool-darwin",
        src = prefix + "/bin/llvm-libtool-darwin",
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-dwp",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/llvm-dwp",
        src = prefix + "/bin/llvm-dwp",
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-objcopy",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/llvm-objcopy",
        src = prefix + "/bin/llvm-objcopy",
    )

    _bootstrap_tool_binary(
        name = prefix + "/bin/llvm-strip",
        actual = "@llvm-project//llvm:llvm.stripped",
        **bootstrap_tool_kwargs
    )

    cc_tool(
        name = prefix + "/llvm-strip",
        src = prefix + "/bin/llvm-strip",
        # TODO: Remove this once rules_cc includes validate_static_library in
        # all_files, or cc_static_library uses the validate action's files
        # directly. This hangs validator files off strip because strip is an
        # exec-configured tool already included in rules_cc 0.2.18's legacy
        # file groups.
        data = [
            prefix + "/bin/static-library-validator",
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
        exec_prefix = _exec_prefix(exec_os, exec_cpu)
        instrumented_prefix = "instrumented_" + exec_prefix
        stage1_prefix = "stage1_" + exec_prefix

        _declare_exec_platform(exec_os, exec_cpu)
        declare_tool_map(
            exec_os,
            exec_cpu,
            prefix = exec_prefix,
            fdo_profile = "//toolchain/bootstrap:llvm_fdo_profdata",
        )
        declare_tool_map(
            exec_os,
            exec_cpu,
            prefix = instrumented_prefix,
            profile_instrumented = True,
        )
        declare_tool_map(
            exec_os,
            exec_cpu,
            prefix = stage1_prefix,
        )

        for toolchain_kind, tool_prefix, target_setting in [
            ("bootstrap", exec_prefix, "@llvm//toolchain:bootstrapped_toolchain"),
            ("instrumented", instrumented_prefix, "@llvm//toolchain:instrumented_toolchain"),
            ("stage1", stage1_prefix, "@llvm//toolchain:stage1_toolchain"),
        ]:
            cc_toolchain_name = "{}_{}_{}_cc_toolchain".format(toolchain_kind, exec_os, exec_cpu)

            # Even though `tool_map` has an exec transition, Bazel doesn't properly handle
            # binding a single `cc_toolchain` to multiple toolchains with different `exec_compatible_with`.
            # See https://github.com/bazelbuild/rules_cc/issues/299#issuecomment-2660340534
            cc_toolchain(
                name = cc_toolchain_name,
                tool_map = select({
                    "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": ":{}/tools_with_libtool".format(tool_prefix),
                    "//conditions:default": ":{}/default_tools".format(tool_prefix),
                }),
                extra_args = [
                    ":{}/header-parser-args".format(tool_prefix),
                    ":{}/static-library-validator-args".format(tool_prefix),
                ],
            )

            for (target_os, target_cpu) in targets:
                native.toolchain(
                    name = "{}_{}_{}_to_{}_{}".format(toolchain_kind, exec_os, exec_cpu, target_os, target_cpu),
                    exec_compatible_with = [
                        "@platforms//cpu:{}".format(exec_cpu),
                        "@platforms//os:{}".format(exec_os),
                    ],
                    target_compatible_with = [
                        "@platforms//cpu:{}".format(target_cpu),
                        "@platforms//os:{}".format(target_os),
                    ],
                    target_settings = [
                        target_setting,
                    ],
                    toolchain = cc_toolchain_name,
                    toolchain_type = "@bazel_tools//tools/cpp:toolchain_type",
                    visibility = ["//visibility:public"],
                )
