load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo", "bool_flag", "string_flag")

OPTIMIZATION_MODES = [
    "debug",
    "optimized",
]

FASTBUILD_OPTIMIZATION_MODES = [
    "O0",
    "O1",
    "O2",
    "O3",
    "Og",
    "Os",
    "Oz",
]

SANITIZERS = [
    "ubsan",
    "cfi",
    "msan",
    "dfsan",
    "nsan",
    "safestack",
    "rtsan",
    "tysan",
    "tsan",
    "asan",
    "lsan",
    "xray",
    "fuzzer",
    "profile",
]

def _is_exec_configuration(ctx):
    # TODO(cerisier): Is there a better way to detect cfg=exec?
    return ctx.genfiles_dir.path.find("-exec") != -1

def _target_bool_flag_impl(ctx):
    value = str(ctx.attr.setting[BuildSettingInfo].value).lower()
    if _is_exec_configuration(ctx):
        value = "false"
    return [config_common.FeatureFlagInfo(value = value)]

_target_bool_flag = rule(
    implementation = _target_bool_flag_impl,
    attrs = {
        "setting": attr.label(mandatory = True),
    },
)

def _host_bool_flag_impl(ctx):
    value = str(ctx.attr.setting[BuildSettingInfo].value).lower()
    if not _is_exec_configuration(ctx):
        value = "false"
    return [config_common.FeatureFlagInfo(value = value)]

_host_bool_flag = rule(
    implementation = _host_bool_flag_impl,
    attrs = {
        "setting": attr.label(mandatory = True),
    },
)

def _declare_sanitizer_config_setting(sanitizer):
    target_setting_name = "target_" + sanitizer
    target_feature_name = sanitizer + "_target_config"
    target_config_setting = target_setting_name + "_enabled"
    _target_bool_flag(
        name = target_feature_name,
        # not target_setting_name
        setting = sanitizer,
    )
    native.config_setting(
        name = target_config_setting,
        flag_values = {
            target_feature_name: "true",
        },
    )

    host_setting_name = "host_" + sanitizer
    host_feature_name = sanitizer + "_host_config"
    host_config_setting = host_setting_name + "_enabled"
    _host_bool_flag(
        name = host_feature_name,
        setting = host_setting_name,
    )
    native.config_setting(
        name = host_config_setting,
        flag_values = {
            host_feature_name: "true",
        },
    )

    selects.config_setting_group(
        name = sanitizer + "_enabled",
        match_any = [
            target_config_setting,
            host_config_setting,
        ],
    )

def config_settings():
    # This flag controls the optimization mode for the compilation of the target
    # prequisites like the standard C library, the C++ standard library,
    # the unwinder, etc.
    #
    # Setting this to "debug" will compile these libraries with debug symbols,
    # frame pointers where applicable, and no optimizations.
    string_flag(
        name = "runtimes_optimization_mode",
        values = OPTIMIZATION_MODES,
        build_setting_default = "optimized",
    )

    for optimization_mode in OPTIMIZATION_MODES:
        native.config_setting(
            name = "runtimes_optimization_mode_{}".format(optimization_mode),
            flag_values = {
                ":runtimes_optimization_mode": optimization_mode,
            },
        )

    # This flag controls the optimization level used when compiling in fastbuild
    # mode (-c fastbuild).
    string_flag(
        name = "fastbuild_optimization_mode",
        values = FASTBUILD_OPTIMIZATION_MODES,
        build_setting_default = "O0",
        scope = "target",
    )

    for optimization_mode in FASTBUILD_OPTIMIZATION_MODES:
        native.config_setting(
            name = "fastbuild_optimization_mode_{}".format(optimization_mode),
            flag_values = {
                ":fastbuild_optimization_mode": optimization_mode,
            },
        )

    # This flag controls whether we compile and link with --sysroot=/dev/null
    # to ensure hermeticity.
    #
    # This is useful if dependencies that you do not control link against host system
    # libraries and you want to allow this behavior. (Hello rust_std).
    bool_flag(
        name = "empty_sysroot",
        build_setting_default = True,
    )

    # This flag makes a dummy gcc_s library to link against.
    #
    # libgcc_s is a shared library (only libgcc_s.so exists) that is required
    # when creating or linking against a shared library that uses c++ exceptions
    # that may cross the library boundary.
    #
    # This toolchain currently doesn't support linking dynamically against an
    # unwinder, which means that this toolchain doesn't support cross boundary
    # c++ exceptions for the moment (and the only unwinder supported is libunwind).
    # Yet, it is possible for dependencies that you do not control to pass -lgcc_s
    # linker flags.
    #
    # Since rustc passes this flag, we default to enabling this flag to make this toolchain
    # more broadly compatible out-of-the-box. If you know what you are doing and do not want
    # to no-op these flags, you can disable this behavior.
    #
    # In theory, we should implement llvm-libgcc and provide these libs into the resource directory.
    bool_flag(
        name = "experimental_stub_libgcc_s",
        build_setting_default = True,
    )

    # This flag strips directory components from the source paths that ASan and
    # UBSan embed in compiled objects, but only for compile command lines that
    # carry no `source_file` variable.
    #
    # Bazel's own C/C++ actions always set `source_file` and pass workspace
    # relative paths, so their sanitizer metadata is already reproducible and is
    # left untouched. Command lines without a `source_file` are the ones other
    # rule sets extract from this toolchain to drive a foreign build system
    # (rules_foreign_cc for CMake/autotools, rules_rust's cargo_build_script via
    # cc-rs, the $(CC_FLAGS) make variable). Those build systems typically
    # compile with absolute paths, and neither -ffile-prefix-map nor
    # -fdebug-prefix-map rewrites UBSan source locations or ASan global
    # metadata, so the absolute execroot ends up in the artifact. rules_rust
    # rejects such artifacts ("rlib embeds the absolute working directory").
    #
    # When enabled:
    #   * UBSan: -fsanitize-undefined-strip-path-components=-1 (reports from
    #     foreign code show the basename only).
    #   * ASan: -mllvm -asan-globals=0 (foreign code loses global-buffer-overflow
    #     detection; its globals are no longer described with file:line:col).
    #
    # Off by default because both are observable behavior changes.
    bool_flag(
        name = "sanitizer_strip_foreign_source_paths",
        build_setting_default = False,
    )

    for sanitizer in SANITIZERS:
        bool_flag(
            name = sanitizer,
            build_setting_default = False,
        )
        bool_flag(
            name = "host_{}".format(sanitizer),
            build_setting_default = False,
        )
        _declare_sanitizer_config_setting(sanitizer)
