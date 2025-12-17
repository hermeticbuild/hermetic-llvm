load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_features//:features.bzl", "bazel_features")

def _wasi_extension_impl(module_ctx):
    """Implementation of the wasi module extension."""

    http_archive(
        name = "wasi_libc",
        urls = ["https://github.com/WebAssembly/wasi-libc/archive/refs/tags/wasi-sdk-28.zip"],
        strip_prefix = "wasi-libc-wasi-sdk-28",
        build_file = "//runtimes/wasi:BUILD.tpl",
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
    doc = "Extension for downloading and configuring wasi",
)
