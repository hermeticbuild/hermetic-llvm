"""Module extension that creates LLVM minimal toolchain repos."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", _http_archive = "http_archive")
load("//toolchain:selects.bzl", "LLVM_VERSION")

PREBUILT_LLVM_SUFFIX = "-1"

LLVM_TOOLCHAIN_MINIMAL_SHA256 = {
    "darwin-amd64": "59f79d29676e3dec24f387ea5ac523aa55895eeeed1a5b987d0be75e55ece4eb",
    "darwin-arm64": "390796080323f2253c75e17789687f2fbc995cd8dcca5904ea770e6f311ff172",
    "linux-amd64-musl": "5261627da8e5ae6331dc5c95b3a37055e18f68a3e64b503ae8f0bc69947a2eb8",
    "linux-arm64-musl": "bd68bf79677489c006bdc4c9cd3416f9f9cc33e4d410d57d258d2608346a7191",
    "windows-amd64": "1b9603ef6e25cf1991f0786c1852fde9dc2b21095ce50563d6c875ed9c01dee9",
    "windows-arm64": "94ca7c793f42a4d48116db1c80ab64edaaa10ce04b13ec56a52a0afedac2b170",
}

def _repo_name(target):
    return "llvm-toolchain-minimal-{llvm_version}-{target}".format(
        llvm_version = LLVM_VERSION,
        target = target.replace("-musl", ""),
    )

def _url(target):
    return "https://github.com/cerisier/toolchains_llvm_bootstrapped/releases/download/llvm-{llvm_version}{prebuilt_llvm_suffix}/llvm-toolchain-minimal-{llvm_version}-{target}.tar.zst".format(
        llvm_version = LLVM_VERSION,
        prebuilt_llvm_suffix = PREBUILT_LLVM_SUFFIX,
        target = target,
    )

def _build_file(target):
    if "windows" in target:
        return Label("//toolchain/llvm:llvm_release_windows.BUILD.bazel")
    return Label("//toolchain/llvm:llvm_release.BUILD.bazel")

def _llvm_toolchain_minimal_impl(mctx):
    for target, sha256 in LLVM_TOOLCHAIN_MINIMAL_SHA256.items():
        _http_archive(
            name = _repo_name(target),
            build_file = _build_file(target),
            sha256 = sha256,
            urls = [_url(target)],
        )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

llvm_toolchain_minimal = module_extension(
    implementation = _llvm_toolchain_minimal_impl,
)
