"""Implicit C++ runtime dependencies for rules_cc targets."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

# The headers that libc++'s own module map (libcxx/include/module.modulemap.in)
# declares textual: they're meant to be included more than once, depend on
# macros of the includer or only compile on some platforms.
_LIBCXX_TEXTUAL_HEADERS = [
    "__config",
    "__config_site",
    "__undef_macros",
    "cassert",
    "csetjmp",
    "version",
]

_LIBCXX_TEXTUAL_DIRECTORIES = [
    "__atomic/support/",
    "__configuration/",
    "__locale_dir/locale_base_api/",
    "__locale_dir/support/",
    "__thread/support/",
    # Not part of libc++'s module map: the C++03 headers redeclare the same
    # entities and have a module map of their own, the others are unmaintained
    # extensions.
    "__cxx03/",
    "__support/",
    "ext/",
]

def _libcxx_module_map_entry(file):
    # Skip files that aren't headers, such as the include-what-you-use mapping
    # libcxx.imp.
    if file.extension not in ("", "h"):
        return None
    path = file.tree_relative_path
    if path in _LIBCXX_TEXTUAL_HEADERS or [d for d in _LIBCXX_TEXTUAL_DIRECTORIES if path.startswith(d)]:
        return "textual " + file.path
    return "header " + file.path

def _module_name(label):
    # Matches the names of the modules that rules_cc generates module maps for,
    # which omit the leading "@@" of main repository labels.
    name = str(label)

    # buildifier: disable=canonical-repository
    if name.startswith("@@//"):
        return name[2:]
    return name

def _libcxx_module_map(ctx):
    module_map = ctx.actions.declare_file(ctx.label.name + ".cppmap")
    args = ctx.actions.args()
    args.add("--module=" + _module_name(ctx.label))
    args.add_all([_module_name(dep.label) for dep in ctx.attr.deps], format_each = "--use=%s")
    args.add("--use=crosstool")
    args.add(module_map)
    header_args = ctx.actions.args()
    header_args.use_param_file("@%s", use_always = True)
    header_args.set_param_file_format("multiline")
    header_args.add_all(ctx.files.hdrs, map_each = _libcxx_module_map_entry, expand_directories = True)
    ctx.actions.run(
        executable = ctx.executable._module_map_generator,
        arguments = [args, header_args],
        # Computing sizes requires the headers as inputs.
        inputs = ctx.files.hdrs,
        outputs = [module_map],
        mnemonic = "CppModuleMap",
        progress_message = "Writing module map %{output}",
    )
    return cc_common.create_module_map(file = module_map)

def _cc_runtimes_library_impl(ctx):
    hdrs = ctx.files.hdrs + ctx.files.exec_hdrs
    if not hdrs:
        return [DefaultInfo(), CcInfo()]

    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    module_map_kwargs = {}
    if ctx.attr.libcxx_module_map:
        module_map_kwargs = {
            "do_not_generate_module_map": True,
            "module_map": _libcxx_module_map(ctx),
        }
    compilation_context, compilation_outputs = cc_common.compile(
        actions = ctx.actions,
        name = ctx.label.name,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        public_hdrs = hdrs,
        compilation_contexts = [dep[CcInfo].compilation_context for dep in ctx.attr.deps],
        **module_map_kwargs
    )

    # Link any object files produced by module code generation.
    if compilation_outputs.objects or compilation_outputs.pic_objects:
        linking_context, _ = cc_common.create_linking_context_from_compilation_outputs(
            actions = ctx.actions,
            name = ctx.label.name,
            cc_toolchain = cc_toolchain,
            feature_configuration = feature_configuration,
            compilation_outputs = compilation_outputs,
        )
    else:
        linking_context = CcInfo().linking_context

    return [
        DefaultInfo(),
        # cc_shared_library follows CcInfo with ctx.label as the owner.
        # CcSharedLibraryHintInfo isn't needed.
        CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        ),
    ]

cc_runtimes_library = rule(
    implementation = _cc_runtimes_library_impl,
    doc = """A header-only runtime library.

It skips the `cc_runtimes` toolchain to avoid a dependency cycle.""",
    attrs = {
        "deps": attr.label_list(
            doc = "Other runtime libraries whose modules this library's headers import.",
            providers = [CcInfo],
        ),
        "exec_hdrs": attr.label_list(
            doc = """Like `hdrs`, but resolved for the execution platform.

Use this for headers of the compiler installation, such as Clang's builtin
headers, which the compiler finds in its own resource directory.""",
            allow_files = True,
            cfg = "exec",
        ),
        "hdrs": attr.label_list(
            doc = "Public headers to compile when `header_modules` is enabled.",
            allow_files = True,
        ),
        "libcxx_module_map": attr.bool(
            doc = """Whether to declare the headers like libc++'s own module map.

Every header in `hdrs` becomes a submodule, except for the ones that libc++
declares textual. Without this, all headers in `hdrs` are modular, and every
submodule compiles its own copy of the textual headers it includes under local
submodule visibility.""",
        ),
        "_module_map_generator": attr.label(
            default = "//tools/internal:module-map-generator",
            executable = True,
            cfg = "exec",
        ),
    },
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _cc_runtimes_toolchain_impl(ctx):
    return [
        platform_common.ToolchainInfo(
            cc_runtimes_info = struct(
                runtimes = ctx.attr.runtimes,
                copts = [],
            ),
        ),
    ]

cc_runtimes_toolchain = rule(
    implementation = _cc_runtimes_toolchain_impl,
    doc = "The implementation of a `@bazel_tools//tools/cpp:cc_runtimes_toolchain_type` toolchain.",
    attrs = {
        "runtimes": attr.label_list(
            doc = "The libraries to add to the dependencies of every C++ target.",
            providers = [CcInfo],
        ),
    },
)
