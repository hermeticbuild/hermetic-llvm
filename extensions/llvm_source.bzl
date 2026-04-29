load("@bazel_skylib//lib:structs.bzl", "structs")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:local.bzl", "new_local_repository")
load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")

DEFAULT_LLVM_VERSIONS_INDEX_FILE = "//:llvm_versions.json"

_DEFAULT_SOURCE_PATCHES = [
    "//3rd_party/llvm-project/x.x/patches:llvm-extra.patch",
    "//3rd_party/llvm-project/x.x/patches:clang-prepend-arg-reexec.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-sanitizers-ignorelists.patch",
    "//3rd_party/llvm-project/x.x/patches:no_frontend_builtin_headers.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-bzl-library.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-cov-multicall.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-readtapi-multicall.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-driver-tool-order.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-driver-best-tool-match.patch",
    "//3rd_party/llvm-project/x.x/patches:llvm-dsymutil-corefoundation.patch",
    "//3rd_party/llvm-project/x.x/patches:compiler-rt-symbolizer_skip_cxa_atexit.patch",
    "//3rd_party/llvm-project/x.x/patches:lit_test_stub.patch",
]

_LLVM_21_SOURCE_PATCHES = _DEFAULT_SOURCE_PATCHES + [
    "//3rd_party/llvm-project/21.x/patches:llvm-link-multicall.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-bazel9.patch",
    "//3rd_party/llvm-project/21.x/patches:windows_link_and_genrule.patch",
    "//3rd_party/llvm-project/21.x/patches:bundle_resources_no_python.patch",
    "//3rd_party/llvm-project/21.x/patches:no_zlib_genrule.patch",
    "//3rd_party/llvm-project/21.x/patches:no_rules_python.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-overlay-starlark.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-windows-stack-size.patch",
    "//3rd_party/llvm-project/21.x/patches:libcxx-lgamma_r.patch",
    "//3rd_party/llvm-project/21.x/patches:llvm-bazel-blake3-windows-gnu.patch",
]

_LLVM_22_SOURCE_PATCHES = _DEFAULT_SOURCE_PATCHES + [
    "//3rd_party/llvm-project/22.x/patches:llvm-link-multicall.patch",
    "//3rd_party/llvm-project/22.x/patches:llvm-profdata-multicall.patch",
    "//3rd_party/llvm-project/22.x/patches:windows_link_and_genrule.patch",
    "//3rd_party/llvm-project/22.x/patches:bundle_resources_no_python.patch",
    "//3rd_party/llvm-project/22.x/patches:no_rules_python.patch",
    "//3rd_party/llvm-project/22.x/patches:llvm-windows-stack-size.patch",
    "//3rd_party/llvm-project/22.x/patches:libcxx-lgamma_r.patch",
    "//3rd_party/llvm-project/22.x/patches:llvm-bazel-blake3-windows-gnu.patch",
]

_LLVM_PATCHES_BY_MAJOR = {
    21: _LLVM_21_SOURCE_PATCHES,
    22: _LLVM_22_SOURCE_PATCHES,
    # So that anyone can test with the next LLVM major easily.
    23: _LLVM_22_SOURCE_PATCHES,
}

_LLVM_SUPPORT_ARCHIVES = {
    "llvm_zlib": struct(
        build_file = "@llvm-raw//utils/bazel/third_party_build:zlib-ng.BUILD",
        sha256 = "e36bb346c00472a1f9ff2a0a4643e590a254be6379da7cddd9daeb9a7f296731",
        strip_prefix = "zlib-ng-2.0.7",
        urls = ["https://github.com/zlib-ng/zlib-ng/archive/refs/tags/2.0.7.zip"],
    ),
    "llvm_zstd": struct(
        build_file = "@llvm-raw//utils/bazel/third_party_build:zstd.BUILD",
        sha256 = "7c42d56fac126929a6a85dbc73ff1db2411d04f104fae9bdea51305663a83fd0",
        strip_prefix = "zstd-1.5.2",
        urls = ["https://github.com/facebook/zstd/releases/download/v1.5.2/zstd-1.5.2.tar.gz"],
    ),
}

_LLVM_SOURCE_BSDTAR_EXTRA_ARGS = [
    "--no-xattrs",
    "--no-fflags",
    "--no-mac-metadata",
    "--no-same-permissions",
    "--no-acls",
    "-m",
]

def _llvm_source_archive_excludes():
    excludes = [
        "flang-rt",
        "flang",
        "polly",
        "orc-rt",
        "libclc",
        "offload",
        "libc/docs",
        "libc/utils/gn",
    ]

    test_docs_subprojects = [
        "bolt",
        "clang-tools-extra",
        "clang",
        "compiler-rt",
        "libcxx",
        "libcxxabi",
        "libunwind",
        "lld",
        "lldb",
        "llvm",
        "mlir",
    ]

    for subproject in test_docs_subprojects:
        if subproject != "mlir":
            excludes.append("{}/test/*".format(subproject))
        excludes.append("{}/docs/*".format(subproject))

    return excludes

def _create_llvm_raw_repo(mctx, version_config):
    had_override = False

    for module in mctx.modules:
        for tag in module.tags.from_path:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True
            new_local_repository(
                name = "llvm-raw",
                build_file_content = "# EMPTY",
                path = tag.path,
            )

        for tag in module.tags.from_git:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True
            git_repository(name = "llvm-raw", **structs.to_dict(tag))

        for tag in module.tags.from_archive:
            if had_override:
                fail("Only 1 LLVM override is allowed currently!")
            had_override = True

            http_archive(name = "llvm-raw", **structs.to_dict(tag))

    if not had_override:
        http_bsdtar_archive(
            name = "llvm-raw",
            build_file_content = "# EMPTY",
            excludes = _llvm_source_archive_excludes(),
            bsdtar_extra_args = _LLVM_SOURCE_BSDTAR_EXTRA_ARGS,
            **structs.to_dict(version_config.source_archive)
        )

    return had_override

def _parse_llvm_major(llvm_version):
    if not llvm_version:
        fail("LLVM version must not be empty")

    major_token = llvm_version.split(".", 1)[0]
    if not major_token:
        fail("Invalid LLVM version '{}': expected '<major>.<minor>.<patch>'".format(llvm_version))

    if not major_token.isdigit():
        fail("Invalid LLVM version '{}': expected numeric major version prefix".format(llvm_version))

    return int(major_token)

def _source_archive_for_version(llvm_version, source_info, patches):
    return struct(
        strip_prefix = source_info.get("strip_prefix", "llvm-project-{}.src".format(llvm_version)),
        urls = [source_info["url"]],
        sha256 = source_info["sha256"],
        patch_args = ["-p1"],
        patches = patches,
    )

def _version_config_for(llvm_version, llvm_version_index):
    major = _parse_llvm_major(llvm_version)
    source_info = llvm_version_index.get(llvm_version)
    if source_info == None:
        fail("LLVM version '{}' is missing from llvm version index.".format(llvm_version))

    if type(source_info) != "dict":
        fail("Invalid llvm version index entry for '{}': expected dict, got {}".format(llvm_version, type(source_info)))

    if source_info.get("url") == None or source_info.get("sha256") == None:
        fail("Invalid llvm version index entry for '{}': expected keys 'url' and 'sha256'".format(llvm_version))

    return struct(
        major = major,
        source_archive = _source_archive_for_version(llvm_version, source_info, _LLVM_PATCHES_BY_MAJOR.get(major, [])),
    )

def _create_support_archives():
    for name, params in _LLVM_SUPPORT_ARCHIVES.items():
        http_archive(
            name = name,
            build_file = params.build_file,
            sha256 = params.sha256,
            strip_prefix = params.strip_prefix,
            urls = params.urls,
        )

def _llvm_subproject_repository_impl(rctx):
    llvm_root = rctx.path(Label("@llvm-raw//:WORKSPACE")).dirname
    src_dir = llvm_root.get_child(rctx.attr.dir)

    for entry in src_dir.readdir():
        rctx.symlink(entry, entry.basename)

    rctx.file("BUILD.bazel", rctx.read(rctx.attr.build_file))
    return rctx.repo_metadata(reproducible = True)

_llvm_subproject_repository = repository_rule(
    implementation = _llvm_subproject_repository_impl,
    attrs = {
        "build_file": attr.label(allow_single_file = True),
        "dir": attr.string(mandatory = True),
    },
)

def _llvm_config_repository_impl(rctx):
    version = rctx.attr.llvm_version
    parts = version.split(".")
    if len(parts) != 3:
        fail("Invalid LLVM version '{}': expected '<major>.<minor>.<patch>[suffix]'".format(version))

    major = int(parts[0])
    minor = int(parts[1])
    patch = int(parts[2])

    rctx.file("BUILD.bazel", """\
load("@bazel_lib//:bzl_library.bzl", "bzl_library")

bzl_library(
    name = "version",
    srcs = ["version.bzl"],
    visibility = ["//visibility:public"],
)
""")

    rctx.file("version.bzl", """\
LLVM_VERSION_MAJOR = "{major}"
LLVM_VERSION_MINOR = "{minor}"
LLVM_VERSION_PATCH = "{patch}"
LLVM_VERSION = "{version}"

llvm_vars = {{
    "LLVM_VERSION_MAJOR": "{major}",
    "LLVM_VERSION_MINOR": "{minor}",
    "LLVM_VERSION_PATCH": "{patch}",
    "LLVM_VERSION": "{version}",
}}
""".format(
        major = major,
        minor = minor,
        patch = patch,
        version = version,
    ))

    return rctx.repo_metadata(reproducible = True)

_llvm_config_repository = repository_rule(
    implementation = _llvm_config_repository_impl,
    attrs = {
        "llvm_version": attr.string(mandatory = True),
    },
)

def _runtime_build_file(name, label_repo_prefix):
    return "{repo}//3rd_party/llvm-project/{version}/{name}:{name}.BUILD.bazel".format(
        repo = label_repo_prefix,
        name = name,
        version = "x.x",
    )

def _create_runtime_repositories(had_override):
    build_label_repo_prefix = "@llvm" if had_override else ""

    for repo_name, subproject in [
        ("compiler-rt", "compiler-rt"),
        ("libcxx", "libcxx"),
        ("libcxxabi", "libcxxabi"),
        ("libunwind", "libunwind"),
        ("llvm-libc", "libc"),
        ("openmp", "openmp"),
    ]:
        _llvm_subproject_repository(
            name = repo_name,
            build_file = _runtime_build_file(subproject, build_label_repo_prefix),
            dir = subproject,
        )

def _get_llvm_version(mctx):
    module_selected_version = None

    for mod in mctx.modules:
        module_versions = [tag.llvm_version for tag in mod.tags.version]
        if len(module_versions) > 1:
            fail("Only 1 llvm_source.version(...) tag is allowed per module")

        if not module_versions:
            continue

        if getattr(mod, "is_root", False):
            return module_versions[0]

        module_selected_version = module_versions[0]

    if module_selected_version != None:
        return module_selected_version

    fail("Missing llvm_source.version(...): set llvm_source.version(llvm_version = \"<major>.<minor>.<patch>\") in your MODULE.bazel")

def _get_llvm_version_index(mctx):
    decoded = json.decode(mctx.read(Label(DEFAULT_LLVM_VERSIONS_INDEX_FILE)))
    if type(decoded) != "dict":
        fail("Invalid llvm version index in '{}': expected top-level dict".format(DEFAULT_LLVM_VERSIONS_INDEX_FILE))
    return decoded

def _llvm_source_impl(mctx):
    llvm_version = _get_llvm_version(mctx)
    llvm_version_index = _get_llvm_version_index(mctx)
    version_config = _version_config_for(llvm_version, llvm_version_index)

    _llvm_config_repository(
        name = "llvm_config",
        llvm_version = llvm_version,
    )

    had_override = _create_llvm_raw_repo(mctx, version_config)
    _create_support_archives()
    _create_runtime_repositories(had_override)

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

_version_tag = tag_class(
    attrs = {
        "llvm_version": attr.string(mandatory = True),
    },
)

_from_path_tag = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
)

_from_git_tag = tag_class(
    attrs = {
        "remote": attr.string(mandatory = True),
        "commit": attr.string(default = ""),
        "tag": attr.string(default = ""),
        "branch": attr.string(default = ""),
        "shallow_since": attr.string(default = ""),
        "init_submodules": attr.bool(default = False),
        "recursive_init_submodules": attr.bool(default = False),
        "strip_prefix": attr.string(default = ""),
        "patches": attr.label_list(default = []),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
        "patch_cmds_win": attr.string_list(default = []),
        "patch_tool": attr.string(default = ""),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(default = ""),
        "workspace_file": attr.label(),
        "workspace_file_content": attr.string(default = ""),
        "verbose": attr.bool(default = False),
    },
)

_from_archive_tag = tag_class(
    attrs = {
        "url": attr.string(default = ""),
        "urls": attr.string_list(default = []),
        "sha256": attr.string(default = ""),
        "integrity": attr.string(default = ""),
        "netrc": attr.string(default = ""),
        "auth_patterns": attr.string_dict(default = {}),
        "strip_prefix": attr.string(default = ""),
        "add_prefix": attr.string(default = ""),
        "files": attr.string_keyed_label_dict(default = {}),
        "type": attr.string(default = ""),
        "patches": attr.label_list(default = []),
        "patch_strip": attr.int(default = 0),
        "patch_args": attr.string_list(default = ["-p0"]),
        "patch_cmds": attr.string_list(default = []),
        "patch_cmds_win": attr.string_list(default = []),
        "patch_tool": attr.string(default = ""),
        "build_file": attr.label(allow_single_file = True),
        "build_file_content": attr.string(default = ""),
        "workspace_file": attr.label(),
        "workspace_file_content": attr.string(default = ""),
        "canonical_id": attr.string(default = ""),
        "remote_file_urls": attr.string_list_dict(default = {}),
        "remote_file_integrity": attr.string_dict(default = {}),
        "remote_module_file_urls": attr.string_list(default = []),
        "remote_module_file_integrity": attr.string(default = ""),
        "remote_patches": attr.string_dict(default = {}),
        "remote_patch_strip": attr.int(default = 0),
        "includes": attr.string_list(default = []),
        "excludes": attr.string_list(default = []),
        "bsdtar_extra_args": attr.string_list(default = []),
    },
)

llvm_source = module_extension(
    implementation = _llvm_source_impl,
    tag_classes = {
        "version": _version_tag,
        "from_path": _from_path_tag,
        "from_git": _from_git_tag,
        "from_archive": _from_archive_tag,
    },
)
