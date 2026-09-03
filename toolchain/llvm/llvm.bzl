load("@bazel_features//:features.bzl", "bazel_features")
load("@llvm//runtimes:module_map.bzl", "include_path", "module_map")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//:directory.bzl", "headers_directory")
load("//toolchain/args:compiler_resource_headers.bzl", "declare_clang_cl_compile_resource_headers", "declare_clang_compile_resource_headers")

_VALIDATE_STATIC_LIBRARY_TOOL = {
    "@rules_cc//cc/toolchains/actions:validate_static_library": ":static_library_validator",
} if bazel_features.cc.supports_starlarkified_toolchains else {}

def declare_llvm_targets(*, suffix = ""):
    """Declares the Bazel interface of one installed LLVM distribution.

    The bin/* tools and lib/clang/* resource headers below come from the same
    archive and must remain coupled. These targets provide the downloaded
    Stage 0 compiler used to build Stage 1, as well as ordinary prebuilt
    toolchains. Source-built stages declare the analogous tools and install
    their matching source resource headers in //toolchain/bootstrap.
    """

    # Model the resource directory already installed beside this archive's
    # compiler binaries. This is never the LLVM source tree being compiled.
    headers_directory(
        name = "builtin_resource_dir",
        # Grab whichever version-specific dir is there.
        path = native.glob(["lib/clang/*"], exclude_directories = 0)[0],
        visibility = ["//visibility:public"],
    )

    headers_directory(
        name = "builtin_resource_include_dir",
        path = native.glob(["lib/clang/*/include"], exclude_directories = 0)[0],
        visibility = ["//visibility:public"],
    )

    # Convenient exports
    native.exports_files(native.glob(["bin/*"]))

    native.filegroup(
        name = "llvm_bin_directory",
        srcs = ["bin"],
    )

    native.filegroup(
        name = "clangxx_file",
        srcs = ["bin/clang++" + suffix],
    )

    native.filegroup(
        name = "dsymutil_file",
        srcs = ["bin/dsymutil" + suffix],
    )

    native.filegroup(
        name = "strip_file",
        srcs = ["bin/llvm-strip" + suffix],
    )

    cc_tool(
        name = "header_parser",
        src = "@llvm//tools/internal:header-parser",
        data = [
            ":builtin_resource_dir",
            ":clangxx_file",
        ],
        env = {
            "LLVM_CLANGXX": "{clangxx}",
        },
        format = {
            "clangxx": ":clangxx_file",
        },
        allowlist_include_directories = [":builtin_resource_dir"],
    )

    declare_clang_compile_resource_headers(
        name = "compile_resource_dir",
        resource_include_directory = "builtin_resource_include_dir",
        # The clang tool already declares this parent tree. Reuse that exact
        # artifact instead of adding its nested include tree as a second action
        # input, which local Bazel sandboxes cannot materialize concurrently.
        resource_headers_data = "builtin_resource_dir",
        visibility = ["//visibility:public"],
    )

    declare_clang_cl_compile_resource_headers(
        name = "clang_cl_compile_resource_dir",
        resource_include_directory = "builtin_resource_include_dir",
        visibility = ["//visibility:public"],
    )

    cc_tool(
        name = "static_library_validator",
        src = "@llvm//tools/internal:static-library-validator",
        data = [
            "bin/c++filt" + suffix,
            "bin/llvm-nm" + suffix,
        ],
        env = {
            "LLVM_CXXFILT": "{cxxfilt}",
            "LLVM_NM": "{llvm_nm}",
        },
        format = {
            "cxxfilt": "bin/c++filt" + suffix,
            "llvm_nm": "bin/llvm-nm" + suffix,
        },
    )

    cc_tool(
        name = "def_file_generator",
        src = "@llvm//tools/def_file_generator",
        data = ["bin/llvm-nm" + suffix],
        env = {"LLVM_NM": "{llvm_nm}"},
        format = {"llvm_nm": "bin/llvm-nm" + suffix},
    )

    TOOLS_WITHOUT_LINKER = {
        "@rules_cc//cc/toolchains/actions:assembly_actions": ":clang",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang",
        "@rules_cc//cc/toolchains/actions:gcov": ":gcov",
        "@rules_cc//cc/toolchains/actions:llvm_cov": ":llvm-cov",
        "@rules_cc//cc/toolchains/actions:llvm_profdata": ":llvm-profdata",
        "@rules_cc//cc/toolchains/actions:objc_compile": ":clang",
        "@llvm//toolchain:cpp_compile_actions_without_header_parsing": ":clang++",
        "@rules_cc//cc/toolchains/actions:objcopy_embed_data": ":llvm-objcopy",
        "@rules_cc//cc/toolchains/actions:dwp": ":llvm-dwp",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
    }
    BASE_TOOLS = TOOLS_WITHOUT_LINKER | {
        "@rules_cc//cc/toolchains/actions:link_actions": ":lld",
    }

    COMPLETE_ONLY_TOOLS = {
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":header_parser",
    } | _VALIDATE_STATIC_LIBRARY_TOOL

    cc_tool_map(
        name = "default_tools",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    # MSVC ABI actions use the CL/LINK dialect directly. Keep this map separate
    # from MinGW so target ABI, never execution OS, selects the personality.
    MSVC_CONSTRUCTION_TOOLS = {
        "@rules_cc//cc/toolchains/actions:assemble": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:c_compile": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:cpp_compile": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:linkstamp_compile": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:lto_backend": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:preprocess_assemble": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:cpp_header_parsing": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        "@rules_cc//cc/toolchains/actions:cpp_link_executable": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:cpp_link_dynamic_library": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:cpp_link_nodeps_dynamic_library": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:objc_executable": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:lto_index_for_executable": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:lto_index_for_dynamic_library": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:lto_index_for_nodeps_dynamic_library": ":clang-cl",
        "@rules_cc//cc/toolchains/actions:strip": ":llvm-strip",
    }

    MSVC_COMPLETE_TOOLS = MSVC_CONSTRUCTION_TOOLS | {
        "@rules_cc//cc/toolchains/actions:generate_def_file": ":def_file_generator",
    } | _VALIDATE_STATIC_LIBRARY_TOOL

    cc_tool_map(
        name = "complete_tools_for_msvc",
        tools = MSVC_COMPLETE_TOOLS,
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "construction_tools_for_msvc",
        tools = MSVC_CONSTRUCTION_TOOLS,
        visibility = ["//visibility:public"],
    )

    native.alias(
        name = "tools_for_msvc_for_runtime",
        actual = select({
            "@llvm//toolchain:runtimes_all": ":complete_tools_for_msvc",
            "//conditions:default": ":construction_tools_for_msvc",
        }),
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_interface_libraries",
        tools = TOOLS_WITHOUT_LINKER | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:link_executable_actions": ":lld",
            "@rules_cc//cc/toolchains/actions:dynamic_library_link_actions": ":link-wrapper",
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "staged_default_tools",
        tools = BASE_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "staged_tools_with_libtool",
        tools = BASE_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-libtool-darwin",
        },
        visibility = ["//visibility:public"],
    )

    native.alias(
        name = "default_tools_for_runtime",
        actual = select({
            "@llvm//toolchain:runtimes_all": ":default_tools",
            "//conditions:default": ":staged_default_tools",
        }),
        visibility = ["//visibility:public"],
    )

    native.alias(
        name = "tools_with_libtool_for_runtime",
        actual = select({
            "@llvm//toolchain:runtimes_all": ":tools_with_libtool",
            "//conditions:default": ":staged_tools_with_libtool",
        }),
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_libtool",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-libtool-darwin",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_dsym",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:link_actions": ":link-wrapper",
            "@rules_cc//cc/toolchains/actions:ar_actions": ":llvm-ar",
        },
        visibility = ["//visibility:public"],
    )

    cc_tool_map(
        name = "tools_with_dsym_and_libtool",
        tools = BASE_TOOLS | COMPLETE_ONLY_TOOLS | {
            "@rules_cc//cc/toolchains/actions:link_actions": ":link-wrapper",
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
        name = "clang-cl",
        src = "bin/clang-cl" + suffix,
        data = [
            ":builtin_resource_include_dir",
            "bin/lld-link" + suffix,
        ],
        capabilities = [
            "@rules_cc//cc/toolchains/capabilities:has_configured_linker_path",
            "@rules_cc//cc/toolchains/capabilities:supports_dynamic_linker",
            "@rules_cc//cc/toolchains/capabilities:supports_interface_shared_libraries",
        ],
        env = {
            # Presence suppresses clang-cl's Visual Studio library probing;
            # /lldignoreenv prevents the child linker from consuming it.
            "LIB": "__hermetic_llvm_empty_lib__",
        },
        allowlist_include_directories = [":builtin_resource_include_dir"],
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
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_start_end_lib"],
    )

    cc_tool(
        name = "link-wrapper",
        src = "@llvm//tools/internal:link-wrapper",
        data = [
            ":clangxx_file",
            ":dsymutil_file",
            ":strip_file",
            "bin/ld.lld" + suffix,
            "bin/ld64.lld" + suffix,
            "bin/lld" + suffix,
            "bin/llvm-ifs" + suffix,
            "bin/llvm-nm" + suffix,
            "bin/llvm-readtapi" + suffix,
            "bin/wasm-ld" + suffix,
        ],
        capabilities = [
            "@rules_cc//cc/toolchains/capabilities:has_configured_linker_path",
            "@rules_cc//cc/toolchains/capabilities:supports_interface_shared_libraries",
            "@rules_cc//cc/toolchains/capabilities:supports_start_end_lib",
        ],
        env = {
            "COMPILER_PATH": "{llvm_bin}/llvm-",
            "LLVM_CLANGXX": "{clangxx}",
            "LLVM_DSYMUTIL": "{dsymutil}",
            "LLVM_IFS": "{llvm_ifs}",
            "LLVM_NM": "{llvm_nm}",
            "LLVM_READTAPI": "{llvm_readtapi}",
            "LLVM_STRIP": "{strip}",
        },
        format = {
            "clangxx": ":clangxx_file",
            "dsymutil": ":dsymutil_file",
            "llvm_bin": ":llvm_bin_directory",
            "llvm_ifs": "bin/llvm-ifs" + suffix,
            "llvm_nm": "bin/llvm-nm" + suffix,
            "llvm_readtapi": "bin/llvm-readtapi" + suffix,
            "strip": ":strip_file",
        },
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
        name = "gcov",
        src = "bin/gcov" + suffix,
    )

    cc_tool(
        name = "llvm-cov",
        src = "bin/llvm-cov" + suffix,
    )

    cc_tool(
        name = "llvm-profdata",
        src = "bin/llvm-profdata" + suffix,
    )

    cc_tool(
        name = "llvm-strip",
        src = "bin/llvm-strip" + suffix,
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
            "bin/c++filt" + suffix,
            "bin/llvm-nm" + suffix,
            "bin/gcov" + suffix,
            "bin/llvm-cov" + suffix,
            "bin/llvm-profdata" + suffix,
        ],
    )

    # The include_path graph below defines the toolchain-owned header surface
    # emitted into the generated crosstool module map. Compile actions expose
    # that surface independently through their selected compile-argument graph
    # and per-toolchain additions. When changing header composition, trace both
    # graphs for the active target platform and ABI, then compare the materialized
    # module map with a representative compile action and its declared inputs.

    # macOS: apply the module-map/compile-action alignment invariant above.
    include_path(
        name = "macos_target_headers",
        srcs = [
            ":builtin_resource_dir",
            "@macos_sdk//sysroot",
        ],
    )

    # Linux: apply the module-map/compile-action alignment invariant above.
    include_path(
        name = "linux_target_headers",
        srcs = [
            ":builtin_resource_dir",
        ] + select({
            "@llvm//toolchain:runtimes_all": [
                "@llvm//runtimes/cxxstdlib:headers_include_search_directory",
                "@llvm//runtimes/cxxstdlib:abi_headers_include_search_directory",
            ],
            "//conditions:default": [],
        }) + [
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

    # Windows MinGW: apply the module-map/compile-action alignment invariant above.
    include_path(
        name = "windows_mingw_target_headers",
        srcs = [
            ":builtin_resource_dir",
        ] + select({
            "@llvm//toolchain:runtimes_all": [
                "@llvm//runtimes/cxxstdlib:headers_include_search_directory",
                "@llvm//runtimes/cxxstdlib:abi_headers_include_search_directory",
            ],
            "//conditions:default": [],
        }) + [
            "@mingw//:mingw_generated_headers_crt_directory",
            "@mingw//:mingw_w64_headers_include_directory",
            "@mingw//:mingw_w64_headers_crt_directory",
            "@mingw//:mingw_w64_winpthreads_include_directory",
        ],
    )

    # Windows MSVC: apply the module-map/compile-action alignment invariant above.
    # Keep the filtered VC compiler/runtime surface separate from the excluded
    # Microsoft STL headers.
    include_path(
        name = "windows_msvc_target_headers",
        srcs = [
            ":builtin_resource_dir",
        ] + select({
            "@llvm//toolchain:runtimes_all": [
                "@llvm//runtimes/cxxstdlib:headers_include_search_directory",
                "@llvm//runtimes/cxxstdlib:abi_headers_include_search_directory",
            ],
            "//conditions:default": [],
        }),
        umbrella_directories = [
            "@llvm//runtimes/msvc:msvc_com_support_headers",
            "@llvm//runtimes/msvc:msvc_vcruntime_headers",
            "@llvm//runtimes/msvc:winsdk_ucrt_include",
            "@llvm//runtimes/msvc:winsdk_shared_include",
            "@llvm//runtimes/msvc:winsdk_um_include",
            "@llvm//runtimes/msvc:winsdk_winrt_include",
        ],
    )

    native.alias(
        name = "windows_target_headers",
        actual = select({
            "@llvm//constraints/windows/abi:msvc": ":windows_msvc_target_headers",
            "//conditions:default": ":windows_mingw_target_headers",
        }),
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
