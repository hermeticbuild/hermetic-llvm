"""Binds an LLVM installation to the released Cosmopolitan linker and fixupobj."""

load("@rules_cc//cc/toolchains:tool.bzl", "cc_tool")
load("@rules_cc//cc/toolchains:tool_map.bzl", "cc_tool_map")
load("//runtimes/cosmo:host_tools.bzl", "APE_LOADERS")

def cosmo_tools(name, *, exec_os, exec_cpu, clang, clangxx, ar, strip, resource_include_dir):
    loader = APE_LOADERS.get((exec_os, exec_cpu))
    if loader == None:
        return
    fixupobj = Label("@cosmopolitan_sdk//:fixupobj")
    for tool, compiler in [("clang", clang), ("clang++", clangxx)]:
        cc_tool(
            name = name + "/" + tool,
            src = Label("//runtimes/cosmo:driver.sh"),
            data = [compiler, loader, fixupobj, resource_include_dir],
            allowlist_include_directories = [resource_include_dir],
            env = {
                "COSMO_APE_LOADER": "{loader}",
                "COSMO_CLANG": "{compiler}",
                "COSMO_RESOURCE_INCLUDE": "{resource_include_dir}",
                "COSMO_FIXUPOBJ": "{fixupobj}",
            },
            format = {
                "compiler": compiler,
                "fixupobj": fixupobj,
                "loader": loader,
                "resource_include_dir": resource_include_dir,
            },
        )

    cc_tool_map(
        name = name,
        tools = {
            "@rules_cc//cc/toolchains/actions:ar_actions": ar,
            "@rules_cc//cc/toolchains/actions:assembly_actions": name + "/clang",
            "@rules_cc//cc/toolchains/actions:c_compile": name + "/clang",
            "@rules_cc//cc/toolchains/actions:link_executable_actions": name + "/clang++",
            "@llvm//toolchain:cpp_compile_actions_without_header_parsing": name + "/clang++",
            "@rules_cc//cc/toolchains/actions:strip": strip,
        },
        visibility = ["//visibility:public"],
    )
