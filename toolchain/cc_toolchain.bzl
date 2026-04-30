load("@rules_cc//cc/toolchains:feature_set.bzl", "cc_feature_set")
load("@rules_cc//cc/toolchains:toolchain.bzl", _cc_toolchain = "cc_toolchain")

def cc_toolchain(name, tool_map, module_map = None, extra_args = []):
    cc_feature_set(
        name = name + "_known_features",
        all_of = [
            "@rules_cc//cc/toolchains/args/layering_check:layering_check",
            "@rules_cc//cc/toolchains/args/layering_check:use_module_maps",
            "@llvm//toolchain/features:static_link_cpp_runtimes",
            "@llvm//toolchain/features/runtime_library_search_directories:feature",
            "@llvm//toolchain/features:parse_headers",
            "@llvm//toolchain/features:external_include_paths",
            "@llvm//toolchain/features:generate_pdb_file",
            # TODO: Restore this after a rules_cc release includes the macOS
            # and Windows distributed ThinLTO arguments and uses NUL for
            # Windows ThinLTO backends without an index.
            # "@rules_cc//cc/toolchains/args/thin_lto:feature",
            "@llvm//toolchain/features/thin_lto:feature",
        ] + select({
            "@llvm//toolchain:macos_complete": [
                "@llvm//toolchain/features:generate_dsym_file",
            ],
            "//conditions:default": [],
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
        name = name + "_enabled_features",
        all_of = select({
            "@platforms//os:linux": [
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
            ],
            "@platforms//os:macos": [],
            "@platforms//os:windows": [
                "@llvm//toolchain/features:static_link_cpp_runtimes",
                "@llvm//toolchain/features/runtime_library_search_directories:feature",
                "@llvm//toolchain/features:def_file",
                "@llvm//toolchain/features:targets_windows",
            ],
            "@platforms//os:none": [],
        }) + select({
            "@llvm//constraints/windows/abi:msvc": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }) + [
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            "@llvm//toolchain/features:module_map_home_cwd",
            # These are "enabled" but they only _actually_ get enabled when the underlying compilation mode is set.
            # This lets us properly order them before user_compile_flags and user_link_flags below.
            "@llvm//toolchain/features:opt",
            "@llvm//toolchain/features:dbg",
            "@llvm//toolchain/features:archive_param_file",
            "@llvm//toolchain/features:parse_headers_wrapper",
        ] + select({
            "@llvm//constraints/windows/abi:msvc": [
                "@llvm//toolchain/features:default_c_std",
                "@llvm//toolchain/features:default_compile_flags_msvc",
                "@llvm//toolchain/features:determinism",
                "@llvm//toolchain/features:dynamic_link_msvcrt",
                "@llvm//toolchain/features:nologo",
                "@llvm//toolchain/features:no_dotd_file",
                "@llvm//toolchain/features:supports_dynamic_linker",
                "@llvm//toolchain/features:supports_interface_shared_libraries",
                "@llvm//toolchain/features:has_configured_linker_path",
                "@llvm//toolchain/features:msvc_implib_flags",
                "@llvm//toolchain/features:compiler_param_file",
                "@llvm//toolchain/features:parse_showincludes",
                "@llvm//toolchain/features:windows_quoting_for_param_files",
            ],
            "//conditions:default": [],
        }) + [
            "@llvm//toolchain/features/legacy:all_legacy_builtin_features",
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    cc_feature_set(
        name = name + "_runtimes_only_enabled_features",
        all_of = select({
            "@llvm//constraints/windows/abi:msvc": [],
            "//conditions:default": [
                "@llvm//toolchain/features:prefer_pic_for_opt_binaries",
            ],
        }) + [
            "@rules_cc//cc/toolchains/args/layering_check:module_maps",
            "@llvm//toolchain/features:module_map_home_cwd",
            "@llvm//toolchain/features:archive_param_file",
        ] + select({
            "@llvm//constraints/windows/abi:msvc": [
                "@llvm//toolchain/features:default_c_std",
                "@llvm//toolchain/features:default_compile_flags_msvc",
                "@llvm//toolchain/features:determinism",
                "@llvm//toolchain/features:nologo",
                "@llvm//toolchain/features:no_dotd_file",
                "@llvm//toolchain/features:compiler_param_file",
                "@llvm//toolchain/features:parse_showincludes",
                "@llvm//toolchain/features:windows_quoting_for_param_files",
            ],
            "//conditions:default": [],
        }) + [
            # Always last (contains user_compile_flags and user_link_flags who should apply last).
            "@llvm//toolchain/features/legacy:experimental_replace_legacy_action_config_features",
        ],
    )

    _cc_toolchain(
        name = name,
        args = select({
            "@llvm//toolchain:runtimes_none": ["@llvm//toolchain/runtimes:toolchain_args"],
            "@llvm//toolchain:runtimes_stage1": ["@llvm//toolchain/runtimes:toolchain_args"],
            "@llvm//toolchain:runtimes_stage1_hosted": ["@llvm//toolchain/runtimes:toolchain_args"],
            "//conditions:default": ["@llvm//toolchain:toolchain_args"],
        }) + [
            # TODO: rules_cc passes extra args to these actions, ideally these would be fixed in rules_cc.
            "@llvm//toolchain/args:ignore_unused_command_line_argument",
        ] + extra_args,
        supports_header_parsing = True,
        supports_param_files = True,
        artifact_name_patterns = select({
            "@platforms//os:linux": [],
            "@platforms//os:macos": [
                "@llvm//toolchain:macos_dynamic_library_pattern",
            ],
            "@platforms//os:windows": [
                "@llvm//toolchain:windows_executable_pattern",
                "@llvm//toolchain:windows_dynamic_library_pattern",
                "@llvm//toolchain:windows_interface_library_pattern",
            ],
            "@platforms//os:none": [],
        }) + select({
            "@llvm//constraints/windows/abi:msvc": [
                "@llvm//toolchain:windows_msvc_alwayslink_static_library_pattern",
                "@llvm//toolchain:windows_msvc_object_file_pattern",
                "@llvm//toolchain:windows_msvc_static_library_pattern",
            ],
            "//conditions:default": [],
        }),
        known_features = select({
            "@llvm//toolchain:runtimes_none": [],
            "@llvm//toolchain:runtimes_stage1": [],
            "@llvm//toolchain:runtimes_stage1_hosted": [],
            "//conditions:default": [name + "_known_features"],
        }),
        enabled_features = select({
            "@llvm//toolchain:runtimes_none": [name + "_runtimes_only_enabled_features"],
            "@llvm//toolchain:runtimes_stage1": [name + "_runtimes_only_enabled_features"],
            "@llvm//toolchain:runtimes_stage1_hosted": [name + "_runtimes_only_enabled_features"],
            "//conditions:default": [name + "_enabled_features"],
        }),
        tool_map = tool_map,
        module_map = module_map,
        static_runtime_lib = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1_hosted": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:static_runtime_lib",
        }),
        dynamic_runtime_lib = select({
            "@llvm//toolchain:runtimes_none": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1": "@llvm//runtimes:none",
            "@llvm//toolchain:runtimes_stage1_hosted": "@llvm//runtimes:none",
            "//conditions:default": "@llvm//runtimes:dynamic_runtime_lib",
        }),
        compiler = select({
            "@llvm//constraints/windows/abi:msvc": "clang-cl",
            "//conditions:default": "clang",
        }),
    )
