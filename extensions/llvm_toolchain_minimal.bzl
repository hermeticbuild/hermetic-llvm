"""Module extension that declares LLVM minimal prebuilt toolchain repositories."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

_TARGETS = [
    "darwin-amd64",
    "darwin-arm64",
    "linux-amd64-musl",
    "linux-arm64-musl",
    "windows-amd64",
    "windows-arm64",
]

_LLVM_TOOLCHAIN_MINIMAL_RELEASES = {
    "llvm-22.1.6-1": {
        "darwin-amd64": "cc79ad7858a02589b334643b38b7112cb2ca7a7546dfefca3feee244f58c209e",
        "darwin-arm64": "da43c29334d92d232f7951ce7be23cf5958f9388fa02ba75a87600a5900b2d52",
        "linux-amd64-musl": "19ecc9a5a3eedd00d7a46e35b292a908ec4eba4f33a40d2566e9a1d2cce31d85",
        "linux-arm64-musl": "3bef1e2cd4de0b35d5305a00d125b8a3257b926171f71ab95bc4ca755fee1647",
        "windows-amd64": "225a8da883543ecd8df865457931d09f38e344243901ad97ddc1fc2a2266563a",
        "windows-arm64": "31f6c4637a27028ad5251ce7aa4ed244f744190eac90cfe7755a7a5d91b11b40",
    },
}

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

def _url(release_key, llvm_version, target):
    return "https://github.com/hermeticbuild/hermetic-llvm/releases/download/{release_key}/llvm-toolchain-minimal-{llvm_version}-{target}.tar.zst".format(
        release_key = release_key,
        llvm_version = llvm_version,
        target = target,
    )

def _build_file(target):
    if target.startswith("windows-"):
        return Label("//toolchain/llvm:llvm_release_windows.BUILD.bazel")
    return Label("//toolchain/llvm:llvm_release.BUILD.bazel")

def _release_sha256(llvm_version, suffix):
    release_key = _release_key(llvm_version, suffix)
    sha256 = _LLVM_TOOLCHAIN_MINIMAL_RELEASES.get(release_key)
    if sha256 == None:
        fail("No llvm-toolchain-minimal prebuilts declared for {}".format(release_key))

    missing = [target for target in _TARGETS if target not in sha256]
    if missing:
        fail("{} is missing llvm-toolchain-minimal sha256 values for {}".format(
            release_key,
            ", ".join(missing),
        ))

    extra = [target for target in sha256.keys() if target not in _TARGETS]
    if extra:
        fail("{} has unknown llvm-toolchain-minimal sha256 targets {}".format(
            release_key,
            ", ".join(extra),
        ))

    return release_key, sha256

def _root_release_suffixes(module_ctx):
    suffixes = {}
    for module in module_ctx.modules:
        if not module.is_root:
            continue
        for release in module.tags.release:
            previous = suffixes.get(release.llvm_version)
            if previous != None and previous != release.suffix:
                fail("Root module requested multiple llvm-toolchain-minimal releases for LLVM {}: {} and {}".format(
                    release.llvm_version,
                    _release_key(release.llvm_version, previous),
                    _release_key(release.llvm_version, release.suffix),
                ))
            suffixes[release.llvm_version] = release.suffix
    return suffixes

def _release_repo_specs(release, root_suffixes):
    suffix = root_suffixes.get(release.llvm_version, release.suffix)
    release_key, sha256 = _release_sha256(release.llvm_version, suffix)
    return {
        _repo_name(release.llvm_version, target): struct(
            build_file = _build_file(target),
            release_key = release_key,
            sha256 = sha256[target],
            urls = [_url(release_key, release.llvm_version, target)],
        )
        for target in _TARGETS
    }

def _same_repo_spec(left, right):
    return left.build_file == right.build_file and left.sha256 == right.sha256 and left.urls == right.urls

def _llvm_toolchain_minimal_impl(module_ctx):
    repo_specs = {}
    root_repos = {}
    root_suffixes = _root_release_suffixes(module_ctx)

    for module in module_ctx.modules:
        for release in module.tags.release:
            release_specs = _release_repo_specs(release, root_suffixes)
            if module.is_root:
                for repo_name in release_specs.keys():
                    root_repos[repo_name] = True

            for repo_name, spec in release_specs.items():
                previous = repo_specs.get(repo_name)
                if previous != None:
                    if not _same_repo_spec(previous, spec):
                        fail("Conflicting llvm-toolchain-minimal release requests: {} and {} both map to repository {}. Choose one release suffix in the root module.".format(
                            previous.release_key,
                            spec.release_key,
                            repo_name,
                        ))
                    continue
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
        "suffix": attr.string(mandatory = True),
    },
)

llvm_toolchain_minimal = module_extension(
    implementation = _llvm_toolchain_minimal_impl,
    doc = "Declares llvm-toolchain-minimal prebuilt compiler repositories.",
    tag_classes = {
        "release": _release_tag,
    },
)
