load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")

IncludePathInfo = provider(
    "IncludePathInfo",
    fields = {
        "textual_headers": "A depset of File objects representing headers to be declared as textual headers.",
    },
)

def _module_map_impl(ctx):
    module_map = ctx.actions.declare_file(ctx.attr.name + ".modulemap")

    include_path_info = ctx.attr.include_path[IncludePathInfo]

    module_map_args = ctx.actions.args()
    module_map_args.set_param_file_format("multiline")
    module_map_args.add('module "crosstool" [system] {')

    # Tree artifacts among the textual headers are expanded to their
    # constituent files at execution time.
    module_map_args.add_joined(
        include_path_info.textual_headers,
        join_with = "\n",
        format_each = "  textual header \"%s\"",
    )

    module_map_args.add("}")

    write_kwargs = {}
    if bazel_features.rules.write_action_has_mnemonic:
        write_kwargs["mnemonic"] = "CppModuleMap"

    ctx.actions.write(
        output = module_map,
        content = module_map_args,
        **write_kwargs
    )
    return DefaultInfo(files = depset([module_map]))

module_map = rule(
    doc = """Generates a Clang module map for the toolchain and system headers.

    All headers are declared as textual headers: this preserves
    `layering_check` semantics, but never requires a compiled module for them
    in `-fmodules` builds (`use_header_modules`), which the toolchain doesn't
    provide.""",
    implementation = _module_map_impl,
    attrs = {
        "include_path": attr.label(
            providers = [IncludePathInfo],
            mandatory = True,
        ),
    },
)

def _include_path_impl(ctx):
    textual_headers = []

    for src in ctx.attr.srcs:
        if DirectoryInfo in src:
            # Source directories are opaque even at execution time, but
            # `headers_directory` enumerates their files in a DirectoryInfo.
            textual_headers.append(src[DirectoryInfo].transitive_files)
        else:
            # Output directories (tree artifacts) are expanded to their
            # constituent files when the module map is written.
            textual_headers.append(src[DefaultInfo].files)

    return [
        IncludePathInfo(
            textual_headers = depset([], transitive = textual_headers),
        ),
    ]

include_path = rule(
    implementation = _include_path_impl,
    attrs = {
        "srcs": attr.label_list(),
    },
)
