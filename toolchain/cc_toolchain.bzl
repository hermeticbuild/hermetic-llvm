load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")

def cc_toolchain(name, tool_map, module_map = None, extra_args = []):
    cc_feature_set(
        name = name + "_known_features",
        all_of = [
            "@rules_cc//cc/toolchains/args/layering_check:layering_check",
            "@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:parse_headers",
        ] + select({
            "@llvm//constraints/windows/abi:gnu": [
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@llvm//constraints/windows/abi:gnullvm": [
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@llvm//constraints/windows/abi:msvc": [
                "@llvm//toolchain/features:targets_windows",
                "@llvm//toolchain/features:supports_interface_shared_libraries",
                "@llvm//toolchain/features:has_configured_linker_path",
                "@llvm//toolchain/features:msvc_implib_flags",
                "@llvm//toolchain/features:compiler_param_file",
                "@llvm//toolchain/features:copy_dynamic_libraries_to_binary",
                "@llvm//toolchain/features:parse_showincludes",
                "@llvm//toolchain/features:windows_quoting_for_param_files",
            ],
            "@llvm//constraints/windows/abi:unconstrained": [
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
        }) + select({
            "@platforms//os:linux": [
                "@rules_cc//cc/toolchains/args/thin_lto:feature",
            ],
            "@platforms//os:windows": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }) + [
            # Those features are enabled internally by --compilation_mode flags family.
            # We add them to the list of known_features but not in the list of enabled_features.
            "@llvm//toolchain/features:all_non_legacy_builtin_features",
            "@llvm//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_known_features",
        all_of = select({
            "@platforms//os:windows": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }) + [
            # TODO(zbarsky): Do we want layering check for runtime libs?
            #"@rules_cc//cc/toolchains/args/layering_check:layering_check",
            #"@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "@llvm//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_enabled_features",
        all_of = select({
            "@platforms//os:linux": [
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "@llvm//toolchain/features:static_link_cpp_runtimes",
            ],
            "@platforms//os:none": [],
        }) + [
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            # These are "enabled" but they only _actually_ get enabled when the underlying compilation mode is set.
            # This lets us properly order them before user_compile_flags and user_link_flags below.
            "@llvm//toolchain/features:opt",
            "@llvm//toolchain/features:dbg",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:parse_headers_wrapper",
            "@llvm//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ] + select({
            "@llvm//constraints/windows/abi:gnu": [
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@llvm//constraints/windows/abi:gnullvm": [
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@llvm//constraints/windows/abi:msvc": [
                "@llvm//toolchain/features:targets_windows",
                "@llvm//toolchain/features:supports_interface_shared_libraries",
                "@llvm//toolchain/features:has_configured_linker_path",
                "@llvm//toolchain/features:msvc_implib_flags",
                "@llvm//toolchain/features:compiler_param_file",
                "@llvm//toolchain/features:parse_showincludes",
                "@llvm//toolchain/features:windows_quoting_for_param_files",
            ],
            "@llvm//constraints/windows/abi:unconstrained": [],
        }) + select({
            "@platforms//os:windows": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }),
    )

    cc_feature_set(
        name = name + "_runtimes_only_enabled_features",
        all_of = select({
            "@platforms//os:windows": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }) + [
            "@llvm//toolchain/features:archive_param_file",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    _cc_toolchain(
        name = name,
        args = select({
            "@llvm//toolchain:runtimes_none": ["@llvm//toolchain/runtimes:toolchain_args"],
            "@llvm//toolchain:runtimes_stage1": ["@llvm//toolchain/runtimes:toolchain_args"],
            "//conditions:default": ["@llvm//toolchain:toolchain_args"],
        }) + [
            # TODO: rules_cc passes extra args to these actions, ideally these would be fixed in rules_cc.
            "@llvm//toolchain/args:ignore_unused_command_line_argument",
        ] + extra_args,
        supports_header_parsing = True,
        supports_param_files = True,
        artifact_name_patterns = select({
            "@platforms//os:macos": [
                "@llvm//toolchain:macos_dynamic_library_pattern",
            ],
            "@platforms//os:windows": [
                "@llvm//toolchain:windows_executable_pattern",
                "@llvm//toolchain:windows_dynamic_library_pattern",
                "@llvm//toolchain:windows_interface_library_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = select({
            "@llvm//toolchain:runtimes_none": [name + "_runtimes_only_known_features"],
            "@llvm//toolchain:runtimes_stage1": [name + "_runtimes_only_known_features"],
            "//conditions:default": [name + "_known_features"],
        }),
        enabled_features = select({
            "@llvm//toolchain:runtimes_none": [name + "_runtimes_only_enabled_features"],
            "@llvm//toolchain:runtimes_stage1": [name + "_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_enabled_features"],
        }),
        tool_map = tool_map,
        module_map = module_map,
        static_runtime_lib = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:static_runtime_lib",
        }),
        dynamic_runtime_lib = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:dynamic_runtime_lib",
        }),
        compiler = select({
            "@llvm//constraints/windows/abi:gnu": "clang",
            "@llvm//constraints/windows/abi:gnullvm": "clang",
            "@llvm//constraints/windows/abi:msvc": "clang-cl",
            "@llvm//constraints/windows/abi:unconstrained": "clang",
        }),
    )
