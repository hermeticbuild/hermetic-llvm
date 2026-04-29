load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _kernel_headers_trampoline_repository_impl(repository_ctx):
    repository_ctx.template("BUILD.bazel", repository_ctx.attr._build_file)

_kernel_headers_trampoline_repository = repository_rule(
    implementation = _kernel_headers_trampoline_repository_impl,
    attrs = {
        "_build_file": attr.label(
            allow_single_file = True,
            default = ":trampoline.BUILD.bazel",
        ),
    },
)

_SUPPORTED_ARCHS = [
    # "alpha",
    # "arc",
    # "arm",
    # "csky",
    # "loongarch",
    # "m68k",
    # "mips",
    # "openrisc",
    # "powerpc",
    "riscv",
    "s390",
    # "sh",
    # "sparc",
    "x86",
    "arm64",
]

def _kernel_headers_impl(module_ctx):
    """Kernel headers extension."""

    decoded_index = {}
    for mod in module_ctx.modules:
        for index_tag in mod.tags.index:
            file_path = module_ctx.path(index_tag.file)
            file_content = module_ctx.read(file_path)
            decoded_index = json.decode(file_content, default = None)

    for version, archs in decoded_index.items():
        for kernel_arch, index_entry in archs.items():
            if kernel_arch not in _SUPPORTED_ARCHS:
                continue
            repo = "linux_kernel_headers_%s.%s" % (kernel_arch, version)
            http_archive(
                name = repo,
                url = index_entry.get("url"),
                sha256 = index_entry.get("sha256"),
                strip_prefix = kernel_arch,
                build_file = ":kernel-headers.BUILD.bazel",
            )

    _kernel_headers_trampoline_repository(
        name = "kernel_headers",
    )

    repos = ["kernel_headers"]
    is_non_dev_dependency = module_ctx.root_module_has_non_dev_dependency
    root_direct_deps = list(repos) if is_non_dev_dependency else []
    root_direct_dev_deps = list(repos) if not is_non_dev_dependency else []

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps,
        root_module_direct_dev_deps = root_direct_dev_deps,
        **metadata_kwargs
    )

kernel_headers_index = tag_class(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            default = ":kernel_headers_index.json",
            mandatory = True,
        ),
    },
)

kernel_headers = module_extension(
    implementation = _kernel_headers_impl,
    tag_classes = {
        "index": kernel_headers_index,
    },
)
