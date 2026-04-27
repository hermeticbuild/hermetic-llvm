load("@bazel_features//:features.bzl", "bazel_features")
load("@llvm//runtimes:module_map.bzl", "include_path", "module_map")
load("@rules_cc//cc/toolchains:args.bzl", "cc_args")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//:directory.bzl", "headers_directory")
load("//toolchain:selects.bzl", "platform_extra_binary", "platform_extra_binary_files")

_VALIDATE_STATIC_LIBRARY_TOOL = {
    "@rules_cc//cc/toolchains/actions:validate_static_library": ":static_library_validator",
} if bazel_features.cc.supports_starlarkified_toolchains else {}

def declare_llvm_targets(*, suffix = ""):
    headers_directory(
        name = "builtin_resource_dir",
        # Grab whichever version-specific dir is there.
        path = native.glob(["lib/clang/*"], exclude_directories = 0)[0],
        visibility = ["//visibility:public"],
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    native.filegroup(
        name = "clangxx_file",
        srcs = ["bin/clang++" + suffix],
    )

    cc_args(
        name = "header_parser_args",
        actions = [
            "@rules_cc//cc/toolchains/actions:cpp_header_parsing",
        ],
        data = [
            ":clangxx_file",
        ],
        env = {
            "LLVM_CLANGXX": "{clangxx}",
        },
        format = {
            "clangxx": ":clangxx_file",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool(
        name = "header_parser",
        src = platform_extra_binary("bin/header-parser"),
        data = [
            ":builtin_resource_dir",
            ":clangxx_file",
        ],
        allowlist_include_directories = [":builtin_resource_dir"],
    )

    cc_args(
        name = "compile_resource_dir",
        actions = [
            "@rules_cc//cc/toolchains/actions:compile_actions",
        ],
        allowlist_include_directories = [
            ":builtin_resource_dir",
        ],
        args = [
            # Use -isystem instead of -resource-dir to avoid conflicts with the
            # linking specific -resource-dir and rules_foreign_cc which does
            # 'CC CFLAGS LDFLAGS'. This has to be last in the search paths
            "-Xclang",
            "-internal-isystem",
            "-Xclang",
            "{resource_dir}/include",
        ],
        data = [
            ":builtin_resource_dir",
        ],
        format = {
            "resource_dir": ":builtin_resource_dir",
        },
        visibility = ["//visibility:public"],
    )

    native.filegroup(
        name = "cxxfilt_file",
        srcs = ["bin/c++filt" + suffix],
    )

    native.filegroup(
        name = "llvm_nm_file",
        srcs = ["bin/llvm-nm" + suffix],
    )

    cc_args(
        name = "static_library_validator_args",
        actions = [
            "@rules_cc//cc/toolchains/actions:validate_static_library",
        ],
        data = [
            ":cxxfilt_file",
            ":llvm_nm_file",
        ],
        env = {
            "LLVM_CXXFILT": "{cxxfilt}",
            "LLVM_NM": "{llvm_nm}",
        },
        format = {
            "cxxfilt": ":cxxfilt_file",
            "llvm_nm": ":llvm_nm_file",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool(
        name = "static_library_validator",
        src = platform_extra_binary("bin/static-library-validator"),
        data = [
            ":cxxfilt_file",
            ":llvm_nm_file",
        ],
    )

    COMMON_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@rules_cc//cc/toolchains/actions:objc_compile": ":clang",
        "@llvm//toolchain:cpp_compile_actions_without_header_parsing": ":clang++",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":header_parser",
        "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:dwp": ":llvm-dwp",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
    } | _VALIDATE_STATIC_LIBRARY_TOOL

    cc_tool_map(
        name = "default_tools",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_libtool",
        tools = COMMON_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-libtool-darwin",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool(
        name = "clang",
        src = "bin/clang" + suffix,
        data = [
            ":builtin_resource_dir",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
        allowlist_include_directories = [":builtin_resource_dir"],
    )

    cc_tool(
        name = "clang++",
        src = "bin/clang++" + suffix,
        data = [
            ":builtin_resource_dir",
        ],
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_pic"],
        allowlist_include_directories = [":builtin_resource_dir"],
    )

    cc_tool(
        name = "lld",
        src = "bin/clang++" + suffix,
        data = [
            "bin/ld.lld" + suffix,
            "bin/ld64.lld" + suffix,
            "bin/lld" + suffix,
            "bin/wasm-ld" + suffix,
        ],
    )

    cc_tool(
        name = "llvm-ar",
        src = "bin/llvm-ar" + suffix,
    )

    cc_tool(
        name = "llvm-libtool-darwin",
        src = "bin/llvm-libtool-darwin" + suffix,
    )

    cc_tool(
        name = "llvm-objcopy",
        src = "bin/llvm-objcopy" + suffix,
    )

    cc_tool(
        name = "llvm-dwp",
        src = "bin/llvm-dwp" + suffix,
    )

    cc_tool(
        name = "llvm-strip",
        src = "bin/llvm-strip" + suffix,
        # TODO: Remove this once rules_cc includes validate_static_library in
        # all_files, or cc_static_library uses the validate action's files
        # directly. This hangs validator files off strip because strip is an
        # exec-configured tool already included in rules_cc 0.2.18's legacy
        # file groups.
        data = platform_extra_binary_files("bin/static-library-validator") + [
            ":cxxfilt_file",
            ":llvm_nm_file",
        ],
    )

    include_path(
        name = "macos_target_headers",
        srcs = [
            ":builtin_resource_dir",
            "@macos_sdk//sysroot",
        ],
    )

    # This must match //toolchain:linux_toolchain_args
    include_path(
        name = "linux_target_headers",
        srcs = [
            ":builtin_resource_dir",
            "@llvm//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@llvm//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@kernel_headers//:kernel_headers_directory",
            "@llvm//sanitizers:sanitizers_headers_include_search_directory",
        ] + select({
            "@llvm//platforms/config:musl": [
                "@llvm//runtimes/musl:musl_headers_include_search_directory",
            ],
            "@llvm//platforms/config:gnu": [
                "@llvm//runtimes/glibc:glibc_headers_include_search_directory",
            ],
        }),
    )

    # this must match //toolchain:windows_toolchain_args
    include_path(
        name = "windows_target_headers",
        srcs = [
            ":builtin_resource_dir",
            "@llvm//runtimes/libcxx:libcxx_headers_include_search_directory",
            "@llvm//runtimes/libcxx:libcxxabi_headers_include_search_directory",
            "@mingw//:mingw_generated_headers_crt_directory",
            "@mingw//:mingw_w64_headers_include_directory",
            "@mingw//:mingw_w64_headers_crt_directory",
            "@mingw//:mingw_w64_winpthreads_include_directory",
        ],
    )

    include_path(
        name = "wasm_target_headers",
        srcs = [
            ":builtin_resource_dir",
            # TODO(zbarsky): We'll want to add wasi libc headers here.
        ],
    )

    module_map(
        name = "module_map",
        include_path = select({
            "@platforms//os:macos": ":macos_target_headers",
            "@platforms//os:linux": ":linux_target_headers",
            "@platforms//os:windows": ":windows_target_headers",
            "@platforms//os:none": ":wasm_target_headers",
        }),
        visibility = ["//visibility:public"],
    )
