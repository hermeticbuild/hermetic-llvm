load("@bazel_features//:features.bzl", "bazel_features")
load("//:http_bsdtar_archive.bzl", "http_bsdtar_archive")
load("//:http_pkg_archive.bzl", "http_pkg_archive")

# Opinionated list of frameworks for minimal macOS SDK.
_DEFAULT_FRAMEWORKS = [
    "CoreFoundation",
    "Foundation",
    "Kernel",
    "OSLog",
    "Security",
    "SystemConfiguration",
]

def _get_sdk_source(mctx):
    module_selected_source = None

    for mod in mctx.modules:
        module_sources = []
        module_sources.extend([struct(kind = "archive", tag = tag) for tag in mod.tags.from_archive])
        module_sources.extend([struct(kind = "local", tag = tag) for tag in mod.tags.from_local])
        module_sources.extend([struct(kind = "host", tag = tag) for tag in mod.tags.from_host])
        if len(module_sources) > 1:
            fail("Only 1 of osx.from_archive(...), osx.from_local(...), or osx.from_host(...) is allowed per module")

        if not module_sources:
            continue

        if getattr(mod, "is_root", False):
            return module_sources[0]

        module_selected_source = module_sources[0]

    if module_selected_source != None:
        return module_selected_source

    fail("Missing macOS SDK source: set osx.from_archive(...), osx.from_local(...), or osx.from_host() in your MODULE.bazel")

def _local_sdk_path_from_host(rctx):
    xcrun = rctx.which("xcrun")
    if xcrun == None:
        fail("osx.from_host() requires xcrun to discover the host macOS SDK")

    result = rctx.execute([xcrun, "--sdk", "macosx", "--show-sdk-path"])
    if result.return_code != 0:
        fail("Failed to discover host macOS SDK with xcrun: {}".format(result.stderr))

    sdk_path = result.stdout.strip()
    if not sdk_path:
        fail("xcrun returned an empty macOS SDK path")
    return sdk_path

def _symlink_if_exists(rctx, src, dst):
    src_path = rctx.path(src)
    if src_path.exists:
        rctx.symlink(src_path, dst)

def _local_macos_sdk_repository_impl(rctx):
    sdk_path = _local_sdk_path_from_host(rctx) if rctx.attr.host else rctx.attr.path
    if not rctx.path(sdk_path).exists:
        fail("macOS SDK path does not exist: {}".format(sdk_path))

    sdk_usr_include = "{}/usr/include".format(sdk_path)
    if not rctx.path(sdk_usr_include).exists:
        fail("macOS SDK is missing usr/include: {}".format(sdk_path))
    sdk_usr_lib = "{}/usr/lib".format(sdk_path)
    if not rctx.path(sdk_usr_lib).exists:
        fail("macOS SDK is missing usr/lib: {}".format(sdk_path))

    rctx.file("sysroot/usr/.bazel_keep", "")
    rctx.file("sysroot/System/Library/Frameworks/.bazel_keep", "")
    rctx.file("sysroot/System/Library/PrivateFrameworks/.bazel_keep", "")

    # Keep local SDK setup simple, but avoid traversing the full Frameworks tree.
    rctx.symlink(rctx.path(sdk_usr_include), "sysroot/usr/include")
    rctx.symlink(rctx.path(sdk_usr_lib), "sysroot/usr/lib")
    _symlink_if_exists(rctx, "{}/SDKSettings.plist".format(sdk_path), "sysroot/SDKSettings.plist")

    for framework in rctx.attr.frameworks:
        _symlink_if_exists(
            rctx,
            "{}/System/Library/Frameworks/{}.framework".format(sdk_path, framework),
            "sysroot/System/Library/Frameworks/{}.framework".format(framework),
        )
        _symlink_if_exists(
            rctx,
            "{}/System/Library/PrivateFrameworks/{}.framework".format(sdk_path, framework),
            "sysroot/System/Library/PrivateFrameworks/{}.framework".format(framework),
        )

    rctx.file("sysroot/BUILD.bazel", """
load("@llvm//:directory.bzl", "headers_directory")

headers_directory(
    name = "sysroot",
    path = ".",
    visibility = ["//visibility:public"],
)
""")

    return rctx.repo_metadata(reproducible = False)

_local_macos_sdk_repository = repository_rule(
    implementation = _local_macos_sdk_repository_impl,
    attrs = {
        "frameworks": attr.string_list(),
        "host": attr.bool(default = False),
        "path": attr.string(),
    },
    doc = "Creates a minimal macOS SDK repository from a local SDK directory.",
)

def _osx_extension_impl(mctx):
    frameworks = []
    libraries = []
    experimental_include_all_sdk_libs = False
    sdk_source = _get_sdk_source(mctx)

    for module in mctx.modules:
        for frameworks_tag in module.tags.frameworks:
            frameworks.extend(frameworks_tag.names)
        for libraries_tag in module.tags.libraries:
            libraries.extend(libraries_tag.names)
        if len(module.tags.experimental_include_all_sdk_libs) > 0:
            experimental_include_all_sdk_libs = True

    experimental_include_all_sdk_libs = mctx.getenv("BAZEL_MACOS_EXPERIMENTAL_INCLUDE_ALL_SDK_LIBS") == "1"
    frameworks_env = mctx.getenv("BAZEL_MACOS_FRAMEWORKS")
    if frameworks_env:
        frameworks = [f.strip() for f in frameworks_env.split(",") if f.strip()]

    if not frameworks:
        frameworks = _DEFAULT_FRAMEWORKS

    # Sandboxing the entire macOS SDK dramatically slows down the build process.
    # Offering a minimal sysroot allows for building basic cross platform applications.
    # Users can extend the sysroot via `osx.frameworks` module extension tag.

    includes = [
        "usr/include/*",
        "usr/lib/libc++*",
    ]

    if experimental_include_all_sdk_libs:
        includes.append("usr/lib/*.tbd")
    else:
        includes.extend([
            "usr/lib/libc.tbd",
            "usr/lib/libcharset*",
            "usr/lib/libdl*",
            "usr/lib/libiconv*",
            "usr/lib/libm.tbd",
            "usr/lib/libobjc*",
            "usr/lib/libresolv*",
            "usr/lib/libpthread.tbd",
            "usr/lib/libSystem*",
        ])

    for library in libraries:
        includes.append("usr/lib/%s*" % library)

    for framework in frameworks:
        includes.append("System/Library/Frameworks/%s.framework/*" % framework)
        includes.append("System/Library/PrivateFrameworks/%s.framework/*" % framework)

    # The following directories are unused, deprecated, or private headers.
    # These components:
    # - Are not part of the documented macOS SDK
    # - Belong to legacy, internal, or low-level subsystems not used in typical builds
    # - May require entitlements or special privileges to use
    excludes = [
        "usr/include/device.modulemap",
        "usr/share/*",
        "usr/libexec/*",
        # "usr/lib/log/*", # SIGNPOST ??
        "usr/lib/swift/*",
        "usr/lib/updaters/*",
        "usr/include/apache2/*",
        "usr/include/AppleArchive/*",
        "usr/include/apr-1/*",
        "usr/include/atm/*",
        "usr/include/bank/*",
        "usr/include/default_pager/*",
        "usr/include/EndpointSecurity/*",
        "usr/include/libexslt/*",
        "usr/include/libxslt/*",
        "usr/include/net-snmp/*",
        "usr/include/netkey/*",
        "usr/include/networkext/*",
        "usr/include/pexpert/*",
        "usr/include/Spatial/*",
        "usr/include/tidy/*",

        # Probably not needed, saves space
        "usr/lib/log/*",
        "usr/lib/rdma/*",
        "usr/lib/system/*",
        "usr/lib/usd/*",
        "usr/lib/i18n/*",
        "usr/lib/libicucore*",

        # These are symlinks to frameworks directory, which might not be included
        "usr/lib/lib*blas*",
        "usr/lib/libclapack.tbd",
        "usr/lib/libcom_err.tbd",
        "usr/lib/libdes425.tbd",
        "usr/lib/libextension.tbd",
        "usr/lib/libf77lapack.tbd",
        "usr/lib/libgssapi_krb5.tbd",
        "usr/lib/libipconfig.tbd",
        "usr/lib/libk5crypto.tbd",
        "usr/lib/libkrb4.tbd",
        "usr/lib/libkrb5.tbd",
        "usr/lib/libkrb524.tbd",
        "usr/lib/libkrb5support.tbd",
        "usr/lib/liblapack.tbd",
        "usr/lib/liblber.tbd",
        "usr/lib/libldap*",
        "usr/lib/libnet*",
        "usr/lib/libtcl*",
        "usr/lib/libtk*",
    ]

    if "IOKit" not in frameworks:
        excludes.append("usr/include/device/*")
    if "Security" not in frameworks:
        excludes.append("usr/include/libDER/*")
    if "Tcl" not in frameworks:
        excludes.append("usr/include/tcl*")
    if "Tk" not in frameworks:
        excludes.append("usr/include/tk*")
    if "PrintCore" not in frameworks:
        excludes.append("usr/include/cups/*")

    if sdk_source.kind == "local":
        _local_macos_sdk_repository(
            name = "macos_sdk",
            frameworks = frameworks,
            path = sdk_source.tag.path,
        )
    elif sdk_source.kind == "host":
        _local_macos_sdk_repository(
            name = "macos_sdk",
            frameworks = frameworks,
            host = True,
        )
    else:
        from_archive = sdk_source.tag
        archive_kwargs = {
            "name": "macos_sdk",
            "files": {
                "sysroot/BUILD.bazel": "//3rd_party/macos_sdk:CLTools_macOSNMOS_SDK.BUILD.bazel",
            },
            "sha256": from_archive.sha256,
            "includes": includes,
            "excludes": excludes,
            "strip_prefix": from_archive.strip_prefix,
            "urls": from_archive.urls,
        }

        if from_archive.type == "pkg":
            http_pkg_archive(
                dst = "sysroot",
                **archive_kwargs
            )
        else:
            http_bsdtar_archive(
                add_prefix = "sysroot",
                type = from_archive.type,
                **archive_kwargs
            )

    metadata_kwargs = {}
    if sdk_source.kind == "archive" and bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return mctx.extension_metadata(**metadata_kwargs)

_frameworks_tag = tag_class(
    attrs = {
        "names": attr.string_list(mandatory = True),
    },
)

_libraries_tag = tag_class(
    attrs = {
        "names": attr.string_list(mandatory = True),
    },
)

_experimental_include_all_sdk_libs_tag = tag_class(
    doc = "Include most usr/lib/*.tbd from the macOS SDK sysroot instead of only the minimal default set. Some libraries that are symlinks to frameworks are still excluded.",
)

_from_archive_tag = tag_class(
    attrs = {
        "urls": attr.string_list(mandatory = True),
        "sha256": attr.string(mandatory = True),
        "strip_prefix": attr.string(mandatory = True),
        "type": attr.string(mandatory = True),
    },
)

_from_local_tag = tag_class(
    attrs = {
        "path": attr.string(mandatory = True),
    },
    doc = "Use a local macOS SDK directory instead of downloading one. The repository is not reproducible.",
)

_from_host_tag = tag_class(
    doc = "Use the host macOS SDK discovered with `xcrun --sdk macosx --show-sdk-path`. The repository is not reproducible.",
)

osx = module_extension(
    implementation = _osx_extension_impl,
    doc = "Generates an OSX sysroot with the requested set of frameworks (or a reasonable default)",
    tag_classes = {
        "from_archive": _from_archive_tag,
        "from_host": _from_host_tag,
        "from_local": _from_local_tag,
        "frameworks": _frameworks_tag,
        "libraries": _libraries_tag,
        "experimental_include_all_sdk_libs": _experimental_include_all_sdk_libs_tag,
    },
)
