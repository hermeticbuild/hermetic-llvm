"""Module extension that declares LLVM minimal prebuilt toolchain repositories."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE = "//extensions:llvm_toolchain_minimal_index.json"

_TARGETS = [
    "darwin-amd64",
    "darwin-arm64",
    "linux-amd64-musl",
    "linux-arm64-musl",
    "windows-amd64",
    "windows-arm64",
]

def _repo_target(target):
    return target.replace("-musl", "")

def _repo_name(llvm_version, target):
    return "llvm-toolchain-minimal-{llvm_version}-{target}".format(
        llvm_version = llvm_version,
        target = _repo_target(target),
    )

def _release_key(llvm_version, suffix):
    return "llvm-{llvm_version}{suffix}".format(
        llvm_version = llvm_version,
        suffix = suffix,
    )

def _build_file(target):
    if target.startswith("windows-"):
        return Label("//toolchain/llvm:llvm_release_windows.BUILD.bazel")
    return Label("//toolchain/llvm:llvm_release.BUILD.bazel")

def _get_index(module_ctx):
    index_file = Label(DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE)
    for module in module_ctx.modules:
        for index in module.tags.index:
            index_file = index.file

    return json.decode(module_ctx.read(module_ctx.path(index_file)), default = None)

def _release_key_for(index, llvm_version, suffix):
    if suffix:
        return _release_key(llvm_version, suffix)
    return index["latest_by_llvm_version"][llvm_version]

def _root_release_keys(module_ctx, index):
    release_keys = {}
    for module in module_ctx.modules:
        if not module.is_root:
            continue

        for release in module.tags.release:
            release_keys[release.llvm_version] = _release_key_for(index, release.llvm_version, release.suffix)
    return release_keys

def _release_repo_specs(release, root_release_keys, index):
    release_key = root_release_keys.get(release.llvm_version)
    if release_key == None:
        release_key = _release_key_for(index, release.llvm_version, release.suffix)

    archives = index["releases"][release_key]
    return {
        _repo_name(release.llvm_version, target): struct(
            build_file = _build_file(target),
            release_key = release_key,
            sha256 = archives[target]["sha256"],
            urls = [archives[target]["url"]],
        )
        for target in _TARGETS
    }

def _llvm_toolchain_minimal_impl(module_ctx):
    index = _get_index(module_ctx)
    repo_specs = {}
    root_repos = {}
    root_release_keys = _root_release_keys(module_ctx, index)

    for module in module_ctx.modules:
        for release in module.tags.release:
            release_specs = _release_repo_specs(release, root_release_keys, index)
            if module.is_root:
                for repo_name in release_specs.keys():
                    root_repos[repo_name] = True

            for repo_name, spec in release_specs.items():
                repo_specs[repo_name] = spec

    for repo_name, spec in repo_specs.items():
        http_archive(
            name = repo_name,
            build_file = spec.build_file,
            sha256 = spec.sha256,
            urls = spec.urls,
        )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    root_direct_deps = sorted(root_repos.keys())
    root_direct_dev_deps = []
    if not module_ctx.root_module_has_non_dev_dependency:
        root_direct_dev_deps = root_direct_deps
        root_direct_deps = []

    return module_ctx.extension_metadata(
        root_module_direct_deps = root_direct_deps,
        root_module_direct_dev_deps = root_direct_dev_deps,
        **metadata_kwargs
    )

_release_tag = tag_class(
    attrs = {
        "llvm_version": attr.string(mandatory = True),
        "suffix": attr.string(default = ""),
    },
)

_index_tag = tag_class(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            default = Label(DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE),
        ),
    },
)

llvm_toolchain_minimal = module_extension(
    implementation = _llvm_toolchain_minimal_impl,
    doc = "Declares llvm-toolchain-minimal prebuilt compiler repositories.",
    tag_classes = {
        "index": _index_tag,
        "release": _release_tag,
    },
)
