load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")

_WINDOWS_MSVC_SUPPORTS_HEADER_PARSING = True

def cc_toolchain(
        name,
        tool_map,
        module_map = None,
        extra_args = None):
    extra_args = extra_args or []
    cc_feature_set(
        name = name + "_msvc_known_features",
        all_of = [
            "@llvm//toolchain/features:opt",
            "@llvm//toolchain/features:opt_stub",
            "@llvm//toolchain/features:dbg",
            "@llvm//toolchain/features:dbg_stub",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:copy_dynamic_libraries_to_binary",
            # The semantic feature is valid: clang-cl renders external include
            # directories through its /imsvc include-path replacement.
            "@llvm//toolchain/features:external_include_paths",
            "@llvm//toolchain/features:generate_pdb_file",
            "@llvm//toolchain/features:no_windows_export_all_symbols",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features:targets_windows",
            "@llvm//toolchain/features:windows_export_all_symbols",
            "@llvm//toolchain/features/legacy:clang_cl_all_legacy_builtin_features",
            "@llvm//toolchain/features/legacy:clang_cl_experimental_replace_legacy_action_config_features",

            # LLVM CL-driver protocol: response files, layering-check
            # tolerance, CL command-line replacements, and the intentional
            # clang-cl-to-lld-link/COFF ThinLTO bridge.
            "@llvm//toolchain/features/clang_cl:known_features",
            # Target ABI: COFF link policy, CRT, validation, and explicit
            # unsupported coverage/sanitizer/header-parsing boundaries.
            "@llvm//toolchain/features/msvc:abi_known_features",
        ] + select({
            "@llvm//toolchain:runtimes_none": [],
            "@llvm//toolchain:runtimes_stage1": [],
            "@llvm//toolchain:runtimes_stage1_hosted": [],
            "//conditions:default": ["@llvm//toolchain/features/clang_cl:compiler_policy_features"],
        }),
    )

    cc_feature_set(
        name = name + "_msvc_enabled_features",
        all_of = [
            "@llvm//toolchain/features:opt",
            "@llvm//toolchain/features:dbg",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features:targets_windows",
            "@llvm//toolchain/features/legacy:clang_cl_all_legacy_builtin_features",

            # Protocol defaults precede target defaults. Keep the legacy
            # replacement set last so user arguments retain their ordering.
            "@llvm//toolchain/features/clang_cl:enabled_features",
            "@llvm//toolchain/features/msvc:abi_enabled_features",
            # Always last: contains user compile/link arguments.
            "@llvm//toolchain/features/legacy:clang_cl_experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_msvc_runtimes_enabled_features",
        all_of = [
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features:targets_windows",
            "@llvm//toolchain/features/legacy:clang_cl_all_legacy_builtin_features",

            # Runtime construction uses the same protocol/target ordering but
            # intentionally omits ordinary opt/dbg defaults.
            "@llvm//toolchain/features/clang_cl:enabled_features",
            "@llvm//toolchain/features/msvc:abi_enabled_features",
            # Always last: contains user compile/link arguments.
            "@llvm//toolchain/features/legacy:clang_cl_experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_msvc_selected_enabled_features",
        all_of = select({
            "@llvm//toolchain:runtimes_none": [name + "_msvc_runtimes_enabled_features"],
            "@llvm//toolchain:runtimes_stage1": [name + "_msvc_runtimes_enabled_features"],
            "@llvm//toolchain:runtimes_stage1_hosted": [name + "_msvc_runtimes_enabled_features"],
            "//conditions:default": [name + "_msvc_enabled_features"],
        }),
    )

    cc_feature_set(
        name = name + "_generic_known_features",
        all_of = [
            "@rules_cc//cc/toolchains/args/layering_check:layering_check",
            "@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features/runtime_library_search_directories:feature",
            "@llvm//toolchain/features:parse_headers",
            "@llvm//toolchain/features:external_include_paths",
            "@llvm//toolchain/features:generate_pdb_file",
            "@llvm//toolchain/features:fdo_optimize",
            "@rules_cc//cc/toolchains/args/thin_lto:feature",
        ] + select({
            "@platforms//os:linux": [
                "@llvm//toolchain/features/interface_libraries:feature",
            ],
            "@platforms//os:macos": [
                "@llvm//toolchain/features/interface_libraries:feature",
            ],
            "//conditions:default": [],
        }) + select({
            "@llvm//toolchain:macos_complete": [
                "@llvm//toolchain/features:generate_dsym_file",
            ],
            "//conditions:default": [],
        }) + [
            # Those features are enabled internally by --compilation_mode flags family.
            # We add them to the list of known_features but not in the list of enabled_features.
            "@llvm//toolchain/features:all_non_legacy_builtin_features",
            "@llvm//toolchain/features:compiler_policy_features",
            "@llvm//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_generic_enabled_features",
        all_of = select({
            "@platforms//os:linux": [
                "@llvm//toolchain/features/interface_libraries:feature",
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:macos": [
                "@llvm//toolchain/features/interface_libraries:feature",
                # macOS links libc++ from the SDK, so it doesn't statically link
                # the C++ runtimes. But it does need dynamic runtime libs (e.g.
                # sanitizer dylibs) placed in runfiles with an @loader_path rpath,
                # which these two features provide. static_link_cpp_runtimes is
                # required for the toolchain to consult dynamic_runtime_lib; it is
                # a no-op for the (empty) macOS C++ runtime libs.
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:windows": [
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
                "@rules_cc//cc/toolchains/args/def_file:def_file",
                "@llvm//toolchain/features:targets_windows",
            ],
            "@platforms//os:none": [],
        }) + [
            "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            "@llvm//toolchain/features:sanitize_pwd",
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            "@llvm//toolchain/features:module_map_home_cwd",
            # These are "enabled" but they only _actually_ get enabled when the underlying compilation mode is set.
            # This lets us properly order them before user_compile_flags and user_link_flags below.
            "@llvm//toolchain/features:opt",
            "@llvm//toolchain/features:dbg",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:parse_headers_wrapper",
            "@llvm//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_generic_runtimes_only_enabled_features",
        all_of = [
            "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            "@llvm//toolchain/features:sanitize_pwd",
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            "@llvm//toolchain/features:module_map_home_cwd",
            "@llvm//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_generic_selected_known_features",
        all_of = select({
            "@llvm//toolchain:runtimes_none": [
                "@llvm//toolchain/features:external_include_paths",
                "@llvm//toolchain/features:fdo_optimize",
            ],
            "@llvm//toolchain:runtimes_stage1": [
                "@llvm//toolchain/features:external_include_paths",
                "@llvm//toolchain/features:fdo_optimize",
            ],
            "@llvm//toolchain:runtimes_stage1_hosted": [
                "@llvm//toolchain/features:external_include_paths",
                "@llvm//toolchain/features:fdo_optimize",
            ],
            "//conditions:default": [name + "_generic_known_features"],
        }),
    )

    cc_feature_set(
        name = name + "_generic_selected_enabled_features",
        all_of = select({
            "@llvm//toolchain:runtimes_none": [name + "_generic_runtimes_only_enabled_features"],
            "@llvm//toolchain:runtimes_stage1": [name + "_generic_runtimes_only_enabled_features"],
            "@llvm//toolchain:runtimes_stage1_hosted": [name + "_generic_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_generic_enabled_features"],
        }),
    )

    cc_feature_set(
        name = name + "_selected_known_features",
        all_of = select({
            "@llvm//constraints/windows/abi:msvc": [name + "_msvc_known_features"],
            "//conditions:default": [name + "_generic_selected_known_features"],
        }),
    )

    cc_feature_set(
        name = name + "_selected_enabled_features",
        all_of = select({
            "@llvm//constraints/windows/abi:msvc": [name + "_msvc_selected_enabled_features"],
            "//conditions:default": [name + "_generic_selected_enabled_features"],
        }),
    )

    native.alias(
        name = name + "_generic_static_runtime_lib",
        actual = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1_hosted": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:static_runtime_lib",
        }),
    )

    native.alias(
        name = name + "_static_runtime_lib",
        actual = select({
            "@llvm//constraints/windows/abi:msvc": "@llvm//runtimes:none",
            "//conditions:default": name + "_generic_static_runtime_lib",
        }),
    )

    native.alias(
        name = name + "_generic_dynamic_runtime_lib",
        actual = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1_hosted": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:dynamic_runtime_lib",
        }),
    )

    native.alias(
        name = name + "_dynamic_runtime_lib",
        actual = select({
            "@llvm//constraints/windows/abi:msvc": "@llvm//runtimes:none",
            "//conditions:default": name + "_generic_dynamic_runtime_lib",
        }),
    )

    _cc_toolchain(
        name = name,
        # libc++ headers are part of semantic platform args. Keep Clang's
        # declared resource headers between them and VC/UCRT so libc++
        # include_next wrappers resolve Clang definitions first.
        args = select({
            "@llvm//toolchain:runtimes_none": ["@llvm//toolchain/runtimes:toolchain_args"],
            "@llvm//toolchain:runtimes_stage1": ["@llvm//toolchain/runtimes:toolchain_args"],
            "@llvm//toolchain:runtimes_stage1_hosted": ["@llvm//toolchain/runtimes:toolchain_args"],
            "//conditions:default": ["@llvm//toolchain:toolchain_args"],
        }) + extra_args,
        # Header parsing support is implemented by the selected compiler
        # personality. The MSVC route uses clang-cl's parse-only dialect and an
        # exec-platform wrapper that materializes Bazel's processed-header
        # marker before invoking the compiler.
        supports_header_parsing = select({
            "@llvm//constraints/windows/abi:msvc": _WINDOWS_MSVC_SUPPORTS_HEADER_PARSING,
            "//conditions:default": True,
        }),
        supports_param_files = True,
        artifact_name_patterns = select({
            "@llvm//platforms/config:windows_x86_64_msvc": [
                "@llvm//toolchain:windows_msvc_object_file_pattern",
                "@llvm//toolchain:windows_msvc_static_library_pattern",
                "@llvm//toolchain:windows_msvc_alwayslink_static_library_pattern",
                "@llvm//toolchain:windows_executable_pattern",
                "@llvm//toolchain:windows_dynamic_library_pattern",
                "@llvm//toolchain:windows_interface_library_pattern",
            ],
            "@llvm//platforms/config:windows_aarch64_msvc": [
                "@llvm//toolchain:windows_msvc_object_file_pattern",
                "@llvm//toolchain:windows_msvc_static_library_pattern",
                "@llvm//toolchain:windows_msvc_alwayslink_static_library_pattern",
                "@llvm//toolchain:windows_executable_pattern",
                "@llvm//toolchain:windows_dynamic_library_pattern",
                "@llvm//toolchain:windows_interface_library_pattern",
            ],
            "@platforms//os:macos": [
                "@llvm//toolchain:macos_dynamic_library_pattern",
                "@llvm//toolchain:macos_interface_library_pattern",
            ],
            "@platforms//os:windows": [
                "@llvm//toolchain:windows_executable_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = [name + "_selected_known_features"],
        enabled_features = [name + "_selected_enabled_features"],
        tool_map = tool_map,
        module_map = module_map,
        static_runtime_lib = name + "_static_runtime_lib",
        dynamic_runtime_lib = name + "_dynamic_runtime_lib",
        compiler = select({
            "@llvm//constraints/windows/abi:msvc": "clang-cl",
            "//conditions:default": "clang",
        }),
    )
