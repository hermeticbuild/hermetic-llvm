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

def _get_index_file(module_ctx):
    index_file = Label(DEFAULT_LLVM_TOOLCHAIN_MINIMAL_INDEX_FILE)
    index_seen = False
    for module in module_ctx.modules:
        for index in module.tags.index:
            if not module.is_root:
                fail("Only the root module may set llvm_toolchain_minimal.index(...)")
            if index_seen:
                fail("Only one llvm_toolchain_minimal.index(...) tag is allowed")
            index_file = index.file
            index_seen = True
    return index_file

def _get_index(module_ctx):
    index_file = _get_index_file(module_ctx)
    decoded = json.decode(module_ctx.read(module_ctx.path(index_file)), default = None)
    if type(decoded) != "dict":
        fail("Invalid llvm-toolchain-minimal index in '{}': expected top-level dict".format(index_file))

    if type(decoded.get("latest_by_llvm_version")) != "dict":
        fail("Invalid llvm-toolchain-minimal index in '{}': expected latest_by_llvm_version dict".format(index_file))

    if type(decoded.get("releases")) != "dict":
        fail("Invalid llvm-toolchain-minimal index in '{}': expected releases dict".format(index_file))

    return decoded

def _index_release(index, release_key):
    release = index["releases"].get(release_key)
    if type(release) != "dict":
        fail("No llvm-toolchain-minimal prebuilts declared for {}".format(release_key))

    return release

def _latest_release_key(index, llvm_version):
    release_key = index["latest_by_llvm_version"].get(llvm_version)
    if type(release_key) != "string":
        fail("No latest llvm-toolchain-minimal release declared for LLVM {}".format(llvm_version))

    return release_key

def _resolved_release_key(index, llvm_version, suffix):
    if suffix:
        return _release_key(llvm_version, suffix)
    return _latest_release_key(index, llvm_version)

def _validate_release(release_key, release, llvm_version):
    release_llvm_version = release.get("llvm_version")
    if release_llvm_version != llvm_version:
        fail("{} declares LLVM version {}, expected {}".format(
            release_key,
            release_llvm_version,
            llvm_version,
        ))

    suffix = release.get("suffix")
    if type(suffix) != "string" or not suffix:
        fail("{} must declare a non-empty suffix".format(release_key))

    expected_key = _release_key(llvm_version, suffix)
    if release_key != expected_key:
        fail("{} declares suffix {}, expected release key {}".format(
            release_key,
            suffix,
            expected_key,
        ))

    archives = release.get("archives")
    if type(archives) != "dict":
        fail("{} must declare an archives dict".format(release_key))

    return suffix, archives

def _release_archives(index, llvm_version, suffix):
    release_key = _resolved_release_key(index, llvm_version, suffix)
    release = _index_release(index, release_key)
    _, archives = _validate_release(release_key, release, llvm_version)

    missing = [target for target in _TARGETS if target not in archives]
    if missing:
        fail("{} is missing llvm-toolchain-minimal sha256 values for {}".format(
            release_key,
            ", ".join(missing),
        ))

    extra = [target for target in archives.keys() if target not in _TARGETS]
    if extra:
        fail("{} has unknown llvm-toolchain-minimal sha256 targets {}".format(
            release_key,
            ", ".join(extra),
        ))

    for target in _TARGETS:
        archive = archives[target]
        if type(archive) != "dict":
            fail("{} archive {} must be a dict".format(release_key, target))
        if type(archive.get("url")) != "string" or not archive.get("url"):
            fail("{} archive {} must declare a non-empty url".format(release_key, target))
        if type(archive.get("sha256")) != "string" or not archive.get("sha256"):
            fail("{} archive {} must declare a non-empty sha256".format(release_key, target))

    return release_key, archives

def _root_release_suffixes(module_ctx, index):
    suffixes = {}
    for module in module_ctx.modules:
        if not module.is_root:
            continue
        for release in module.tags.release:
            suffix = release.suffix
            if not suffix:
                release_key = _latest_release_key(index, release.llvm_version)
                latest_release = _index_release(index, release_key)
                suffix, _ = _validate_release(release_key, latest_release, release.llvm_version)

            previous = suffixes.get(release.llvm_version)
            if previous != None and previous != suffix:
                fail("Root module requested multiple llvm-toolchain-minimal releases for LLVM {}: {} and {}".format(
                    release.llvm_version,
                    _release_key(release.llvm_version, previous),
                    _release_key(release.llvm_version, suffix),
                ))
            suffixes[release.llvm_version] = suffix
    return suffixes

def _release_repo_specs(release, root_suffixes, index):
    suffix = root_suffixes.get(release.llvm_version, release.suffix)
    release_key, archives = _release_archives(index, release.llvm_version, suffix)
    return {
        _repo_name(release.llvm_version, target): struct(
            build_file = _build_file(target),
            release_key = release_key,
            sha256 = archives[target]["sha256"],
            urls = [archives[target]["url"]],
        )
        for target in _TARGETS
    }

def _same_repo_spec(left, right):
    return left.build_file == right.build_file and left.sha256 == right.sha256 and left.urls == right.urls

def _llvm_toolchain_minimal_impl(module_ctx):
    index = _get_index(module_ctx)
    repo_specs = {}
    root_repos = {}
    root_suffixes = _root_release_suffixes(module_ctx, index)

    for module in module_ctx.modules:
        for release in module.tags.release:
            release_specs = _release_repo_specs(release, root_suffixes, index)
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
