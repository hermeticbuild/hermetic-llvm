load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules/directory:providers.bzl", "DirectoryInfo")
load("//:directory.bzl", "SourceDirectoryInfo")

IncludePathInfo = provider(
    "IncludePathInfo",
    fields = {
        "submodule_directories": "A depset of File objects representing directories to be included as umbrella submodules.",
        "textual_headers": "A depset of File objects representing headers to be included as textual headers.",
    },
)

def _normalized_path(directory):
    return paths.normalize(directory.path).replace("//", "/")

def _umbrella_submodule(directory):
    return """
  module "{path}" {{
    umbrella "{path}"
  }}""".format(path = _normalized_path(directory))

def _umbrella_entry(directory):
    return "umbrella " + _normalized_path(directory)

def _module_map_impl(ctx):
    module_map = ctx.actions.declare_file(ctx.attr.name + ".modulemap")

    include_path_info = ctx.attr.include_path[IncludePathInfo]

    if ctx.executable.generator:
        # The generator declares textual headers with their size, which lets
        # Clang resolve them lazily instead of stat'ing every one of them
        # whenever the module map is parsed. It thus needs the headers as
        # inputs.
        output_args = ctx.actions.args()
        output_args.add(module_map)
        entry_args = ctx.actions.args()
        entry_args.use_param_file("@%s", use_always = True)
        entry_args.set_param_file_format("multiline")
        entry_args.add_all(
            include_path_info.submodule_directories,
            map_each = _umbrella_entry,
            expand_directories = False,
        )
        entry_args.add_all(include_path_info.textual_headers, format_each = "textual %s")
        ctx.actions.run(
            executable = ctx.executable.generator,
            arguments = [output_args, entry_args],
            inputs = include_path_info.textual_headers,
            outputs = [module_map],
            mnemonic = "CppModuleMap",
            progress_message = "Writing module map %{output}",
        )
        return DefaultInfo(files = depset([module_map]))

    module_map_args = ctx.actions.args()
    module_map_args.set_param_file_format("multiline")
    module_map_args.add('module "crosstool" [system] {')

    module_map_args.add_joined(
        include_path_info.submodule_directories,
        join_with = "\n",
        map_each = _umbrella_submodule,
        expand_directories = False,
    )

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

    Source directories are included as umbrella submodules.
    Individual header files and the contents of output directories (Tree
    Artifacts) are included as textual headers.""",
    implementation = _module_map_impl,
    attrs = {
        "include_path": attr.label(
            providers = [IncludePathInfo],
            mandatory = True,
        ),
        "generator": attr.label(
            doc = """A tool that writes the module map with sizes for textual
            headers. Without it, the module map is written directly.""",
            cfg = "exec",
            executable = True,
        ),
    },
)

def _include_path_impl(ctx):
    submodule_directories = []
    textual_headers_depsets = []

    for src in ctx.attr.srcs:
        if SourceDirectoryInfo in src:
            # Source directories are opaque even at execution time, so they
            # can only be covered by umbrella submodules.
            submodule_directories.append(src[DefaultInfo].files)
        elif DirectoryInfo in src:
            textual_headers_depsets.append(src[DirectoryInfo].transitive_files)
        else:
            # Output directories (tree artifacts) are expanded to their
            # constituent files when the module map is written. Declaring
            # headers as textual rather than covering them with umbrella
            # submodules preserves `layering_check` semantics, but doesn't
            # require a compiled module for them in `-fmodules` builds.
            textual_headers_depsets.append(src[DefaultInfo].files)

    return [
        IncludePathInfo(
            submodule_directories = depset([], transitive = submodule_directories),
            textual_headers = depset([], transitive = textual_headers_depsets),
        ),
    ]

include_path = rule(
    implementation = _include_path_impl,
    attrs = {
        "srcs": attr.label_list(),
    },
)
