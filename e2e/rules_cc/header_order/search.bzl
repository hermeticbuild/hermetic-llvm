"""Capture Clang's effective search list from a native CppCompile action."""

load("@rules_cc//cc:find_cc_toolchain.bzl", "use_cc_toolchain")

_SearchInfo = provider(
    doc = "Files from a Clang verbose header search probe.",
    fields = ["search", "stderr", "preprocessed"],
)

def _search_aspect_impl(target, ctx):
    compiles = [action for action in target.actions if action.mnemonic == "CppCompile"]
    if len(compiles) != 1:
        fail("expected one CppCompile action for %s, got %d" % (target.label, len(compiles)))
    compile_action = compiles[0]
    if not compile_action.argv:
        fail("CppCompile action does not expose its arguments: %s" % target.label)

    search = ctx.actions.declare_file(target.label.name + ".search.txt")
    stderr = ctx.actions.declare_file(target.label.name + ".search.stderr")
    preprocessed = ctx.actions.declare_file(target.label.name + ".search.i")
    arguments = ctx.actions.args()
    arguments.add(search)
    arguments.add(stderr)
    arguments.add(preprocessed)
    arguments.add_all(compile_action.argv)
    ctx.actions.run(
        executable = ctx.executable._capture,
        arguments = [arguments],
        outputs = [search, stderr, preprocessed],
        shadowed_action = compile_action,
        mnemonic = "ClangHeaderSearch",
        progress_message = "Capturing Clang search list for %{label}",
        toolchain = "@bazel_tools//tools/cpp:toolchain_type",
    )
    return [
        _SearchInfo(search = search, stderr = stderr, preprocessed = preprocessed),
        OutputGroupInfo(search_debug = depset([stderr, preprocessed])),
    ]

_search_aspect = aspect(
    implementation = _search_aspect_impl,
    attrs = {
        "_capture": attr.label(
            default = "//header_order:search_capture",
            executable = True,
            cfg = "exec",
        ),
    },
    toolchains = use_cc_toolchain(),
)

def _search_output_impl(ctx):
    result = ctx.attr.target[_SearchInfo]
    return [
        DefaultInfo(files = depset([result.search])),
        OutputGroupInfo(search_debug = depset([result.stderr, result.preprocessed])),
    ]

search_output = rule(
    implementation = _search_output_impl,
    attrs = {
        "target": attr.label(aspects = [_search_aspect], mandatory = True),
    },
)
