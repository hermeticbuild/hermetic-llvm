load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _wasi_extension_impl(module_ctx):
    """Implementation of the wasi module extension."""

    http_archive(
        name = "wasi_libc",
        urls = ["https://github.com/WebAssembly/wasi-libc/archive/refs/tags/wasi-sdk-34.tar.gz"],
        sha256 = "21bc47f96cf0eb535e532697dce4cdfdbc91f59223bdc00d8495d191888c5fe8",
        strip_prefix = "wasi-libc-wasi-sdk-34",
        build_file = "//runtimes/wasi:wasi.BUILD.bazel",
    )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["wasi_libc"],
        root_module_direct_dev_deps = [],
        **metadata_kwargs
    )

wasi = module_extension(
    implementation = _wasi_extension_impl,
    doc = "Extension for downloading and configuring WASI libc.",
)
