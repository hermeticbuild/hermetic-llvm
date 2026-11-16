"""Internal component-linker bindings for concrete LLVM installations."""

load("@bazel_skylib//rules/directory:providers.bzl", "create_directory_info")
load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//platforms:common.bzl", "SUPPORTED_EXECS")

def _component_ld_directory_impl(ctx):
    binary = ctx.file.src
    files = depset([binary])
    return [
        DefaultInfo(files = files),
        create_directory_info(
            entries = {},
            human_readable = str(ctx.label),
            path = binary.dirname,
            transitive_files = files,
        ),
    ]

_component_ld_directory = rule(
    implementation = _component_ld_directory_impl,
    attrs = {"src": attr.label(allow_single_file = True, mandatory = True)},
    cfg = config.none(),
)

def component_tools(name, *, exec_os, exec_cpu, clang, wasm_ld, base_tools, complete_only_tools):
    # Like LLD, this executable must match the concrete compiler installation,
    # irrespective of which platform an independent toolchain lookup prefers.
    supported = (exec_os, exec_cpu) in SUPPORTED_EXECS
    directory = name + "/directory"
    if supported:
        _component_ld_directory(
            name = directory,
            src = Label("@wasm_component_ld_{}_{}//:wasm-component-ld{}".format(
                exec_os,
                exec_cpu,
                ".exe" if exec_os == "windows" else "",
            )),
        )
    cc_tool(
        name = name + "/linker",
        src = clang,
        data = [wasm_ld, directory] if supported else [wasm_ld],
        env = {"COMPILER_PATH": "{component_ld}"} if supported else {},
        format = {"component_ld": directory} if supported else {},
        capabilities = ["@rules_cc//cc/toolchains/capabilities:supports_start_end_lib"],
        target_compatible_with = [] if supported else ["@platforms//:incompatible"],
    )

    tools = base_tools | {
        "@rules_cc//cc/toolchains/actions:link_actions": name + "/linker",
    }
    cc_tool_map(
        name = name + "/staged",
        tools = tools,
    )
    cc_tool_map(
        name = name + "/complete",
        tools = tools | complete_only_tools,
    )
    native.alias(
        name = name,
        actual = select({
            "@llvm//toolchain:runtimes_all": name + "/complete",
            "//conditions:default": name + "/staged",
        }),
        visibility = ["//visibility:public"],
    )
