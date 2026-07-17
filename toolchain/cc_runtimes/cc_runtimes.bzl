"""Libraries that every C++ target implicitly depends on.

rules_cc adds the libraries provided by the `cc_runtimes` toolchain to the
dependencies of every `cc_library`, `cc_binary`, `cc_test`, `cc_import`,
`cc_shared_library` and `objc_library`. This is how the C++ standard library
is attached to all targets at Google (their `_stl` dependency).
"""

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
        textual_hdrs = ctx.files.textual_hdrs,
    )

    # With header module codegen, the module is also compiled into an object
    # file that depending targets link.
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
        CcInfo(
            compilation_context = compilation_context,
            linking_context = linking_context,
        ),
    ]

cc_runtimes_library = rule(
    implementation = _cc_runtimes_library_impl,
    doc = """A header-only library that the `cc_runtimes` toolchain can add to every C++ target.

Unlike `cc_library`, this rule doesn't depend on the `cc_runtimes` toolchain
itself, which would be a dependency cycle for the runtimes it provides.""",
    attrs = {
        "hdrs": attr.label_list(
            doc = "Headers of the library, which are compiled into a header module if the `header_modules` feature is enabled.",
            allow_files = True,
        ),
        "textual_hdrs": attr.label_list(
            doc = "Headers that are included textually rather than compiled into the header module.",
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
