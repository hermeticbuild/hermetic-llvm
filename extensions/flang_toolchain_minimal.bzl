"""Module extension for exact-version minimal Flang prebuilts."""

load("@bazel_features//:features.bzl", "bazel_features")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@llvm_version//:version.bzl", "LLVM_VERSION")

DEFAULT_FLANG_TOOLCHAIN_MINIMAL_INDEX_FILE = "//extensions:flang_toolchain_minimal_index.json"

_TARGETS = [
    "darwin-amd64",
    "darwin-arm64",
    "linux-amd64-musl",
    "linux-arm64-musl",
    "windows-amd64",
    "windows-arm64",
]

def _repo_name(target):
    return "flang-toolchain-minimal-{}".format(target.replace("-musl", ""))

def _missing_release_repository_impl(rctx):
    fail("Flang {} has no indexed minimal prebuilt release".format(rctx.attr.llvm_version))

_missing_release_repository = repository_rule(
    implementation = _missing_release_repository_impl,
    attrs = {"llvm_version": attr.string(mandatory = True)},
)

def _get_index(module_ctx):
    index_file = Label(DEFAULT_FLANG_TOOLCHAIN_MINIMAL_INDEX_FILE)
    dependency_index_file = None

    for module in module_ctx.modules:
        index_files = [index.file for index in module.tags.index]
        if len(index_files) > 1:
            fail("Only 1 flang_toolchain_minimal.index(...) tag is allowed per module")

        if not index_files:
            continue

        if module.is_root:
            index_file = index_files[0]
            break

        dependency_index_file = index_files[0]

    if dependency_index_file != None and index_file == Label(DEFAULT_FLANG_TOOLCHAIN_MINIMAL_INDEX_FILE):
        index_file = dependency_index_file

    return json.decode(module_ctx.read(module_ctx.path(index_file)), default = None)

def _release_repo_specs(index):
    release_key = index.get("latest_by_llvm_version", {}).get(LLVM_VERSION)
    if release_key == None:
        return None
    if not release_key.startswith("flang-{}-r".format(LLVM_VERSION)):
        fail("Flang release {} does not match LLVM {}".format(release_key, LLVM_VERSION))

    archives = index["releases"][release_key]
    return {
        _repo_name(target): struct(
            sha256 = archives[target]["sha256"],
            url = archives[target]["url"],
            suffix = ".exe" if target.startswith("windows-") else "",
        )
        for target in _TARGETS
    }

def _flang_toolchain_minimal_impl(module_ctx):
    repo_specs = _release_repo_specs(_get_index(module_ctx))
    if repo_specs == None:
        for target in _TARGETS:
            _missing_release_repository(
                name = _repo_name(target),
                llvm_version = LLVM_VERSION,
            )
    else:
        build_file = module_ctx.read(Label("//prebuilt/flang:flang_release.BUILD.bazel"))
        for repo_name, spec in repo_specs.items():
            http_archive(
                name = repo_name,
                build_file_content = build_file.format(suffix = spec.suffix),
                sha256 = spec.sha256,
                urls = [spec.url],
            )

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return module_ctx.extension_metadata(**metadata_kwargs)

_index_tag = tag_class(
    attrs = {
        "file": attr.label(
            allow_single_file = True,
            default = Label(DEFAULT_FLANG_TOOLCHAIN_MINIMAL_INDEX_FILE),
        ),
    },
)

flang_toolchain_minimal = module_extension(
    implementation = _flang_toolchain_minimal_impl,
    doc = "Declares exact-version minimal Flang prebuilt repositories for the LLVM version selected by llvm.",
    tag_classes = {"index": _index_tag},
)
