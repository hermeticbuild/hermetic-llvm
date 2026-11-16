"""Implicit C++ runtime dependencies for rules_cc targets."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")

def _cc_runtimes_library_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    compilation_context, compilation_outputs = cc_common.compile(
        actions = ctx.actions,
        name = ctx.label.name,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        public_hdrs = ctx.files.hdrs,
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
        "hdrs": attr.label_list(
            doc = "Public headers to compile when `header_modules` is enabled.",
            allow_files = True,
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
