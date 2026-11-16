load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Versions used by wasi-sdk-34's cmake/wasm-{tools,component-ld}.cmake.
_WASM_TOOLS_SHA256 = {
    ("linux", "aarch64"): "26bb6697e5483cd11bbe4b977a01b41611565cfd2c51a6cb5ad228dc7e48a009",
    ("linux", "x86_64"): "f1620e89cf19ac1b7ec65fd7a542e906ea2745bb0ec435270b35b5fb72d30ba9",
    ("macos", "aarch64"): "f0a585f21ad3b1e8dedec2226fb5decebc2f0be20569b5372c7ce7ee30be23d5",
    ("macos", "x86_64"): "408f9dfa4c41250f8fd0bb1df13d5f144b7953cb8cf09c6128c8817f8840f4cf",
    ("windows", "aarch64"): "14e52837183b1672da35e8151db77e0ea358837ae5cbc183b8f25e5ae58fac1d",
    ("windows", "x86_64"): "6e4fe16d3147240330fc27c88494d85d3eed2179137e559f5c471f9267dbdee8",
}

_COMPONENT_LD_SHA256 = {
    ("linux", "aarch64"): "4fb4b1bb9714a72aea41ded34eacd4df1a1ef338dccaf95f49a4d95b145182cf",
    ("linux", "x86_64"): "fb07d7022859c3892a9243539910747a9c00870ba7abbfb69f22aaddc800f398",
    ("macos", "aarch64"): "583acf6778c2e41fa6b51e40f231007bfe62377de18d4986020f2888239c3aac",
    ("macos", "x86_64"): "59e00c8c23d5a5563af560edbdb8438bbf78b2c1e87cdd269a360269eb1b471f",
    ("windows", "aarch64"): "65dba5c720a13d0a7927921b039a194045313c9150390509fb6a64766ff8c6ec",
    ("windows", "x86_64"): "051cebefe847b2636fa12277cd8e698bfcdae03c2f9dc29e561e9baafaeec220",
}

def _wasi_tools_impl(module_ctx):
    repos = []
    for tool, version, hashes in [
        ("wasm-tools", "1.257.0", _WASM_TOOLS_SHA256),
        ("wasm-component-ld", "v0.5.30", _COMPONENT_LD_SHA256),
    ]:
        for (os, arch), sha256 in hashes.items():
            repo = "{}_{}_{}".format(tool.replace("-", "_"), os, arch)
            archive = "{}-{}-{}-{}".format(tool, version, arch, os)
            tag = version if version.startswith("v") else "v" + version
            file = tool + (".exe" if os == "windows" else "")
            http_archive(
                name = repo,
                urls = ["https://github.com/bytecodealliance/{}/releases/download/{}/{}.{}".format(
                    tool,
                    tag,
                    archive,
                    "zip" if os == "windows" else "tar.gz",
                )],
                strip_prefix = archive,
                sha256 = sha256,
                build_file_content = 'exports_files(["{}"], visibility = ["//visibility:public"])'.format(file),
            )
            repos.append(repo)
    return module_ctx.extension_metadata(
        root_module_direct_deps = repos,
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

wasi_tools = module_extension(
    implementation = _wasi_tools_impl,
    doc = "Pinned wasi-sdk-34 component linker and WIT tools, selected for the execution platform.",
)
