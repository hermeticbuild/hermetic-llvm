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

_DEFAULT_ZIG_LIBC_ARCHIVE = struct(
    sha256 = "553334a7d6453baaa3cdaace52c1cd1044f415c35355569bc8a7408cf295a1bc",
    strip_prefix = "zig/lib/libc",
    type = "tar.gz",
    urls = [
        "https://codeberg.org/ziglang/zig/archive/5cc281e7232b9f1bc5f4d732e4a37fb5df02f780.tar.gz",
    ],
)

_DEFAULT_APPLE_SDK_ARCHIVE = struct(
    sha256 = "edc7ce9b8f09e0c7a39aaa714f941b4c2597f333ec1ffe59a14d67eb36cdb7e7",
    strip_prefix = "Payload/Library/Developer/CommandLineTools/SDKs/MacOSX26.4.sdk",
    type = "pkg",
    urls = [
        "https://swcdn.apple.com/content/downloads/60/13/122-35686-A_30JUXWIJFR/ck0gzuw5qccefzm3ptlwou3pu6a55d0o02/CLTools_macOSNMOS_SDK.pkg",
    ],
)

def _declare_zig_libc_sdk(from_archive):
    http_bsdtar_archive(
        name = "macos_sdk",
        add_prefix = "sysroot",
        files = {
            "sysroot/BUILD.bazel": "//3rd_party/macos_sdk:ZigLibc.BUILD.bazel",
        },
        includes = [
            "darwin",
            "darwin/*",
            "include/any-darwin-any",
            "include/any-darwin-any/*",
        ],
        sha256 = from_archive.sha256,
        strip_prefix = from_archive.strip_prefix,
        type = from_archive.type,
        urls = from_archive.urls,
    )

def _get_from_archive(mctx):
    module_selected_archive = None

    for mod in mctx.modules:
        module_archives = [tag for tag in mod.tags.from_archive]
        if len(module_archives) > 1:
            fail("Only 1 osx.from_archive(...) tag is allowed per module")

        if not module_archives:
            continue

        if getattr(mod, "is_root", False):
            return module_archives[0]

        module_selected_archive = module_archives[0]

    return module_selected_archive

def _declare_apple_sdk(from_archive, frameworks, experimental_include_all_sdk_libs):
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

def _osx_extension_impl(mctx):
    frameworks = []
    experimental_include_all_sdk_libs = False
    from_archive = _get_from_archive(mctx)

    for module in mctx.modules:
        for frameworks_tag in module.tags.frameworks:
            frameworks.extend(frameworks_tag.names)
        if len(module.tags.experimental_include_all_sdk_libs) > 0:
            experimental_include_all_sdk_libs = True

    experimental_include_all_sdk_libs = experimental_include_all_sdk_libs or mctx.getenv("BAZEL_MACOS_EXPERIMENTAL_INCLUDE_ALL_SDK_LIBS") == "1"
    frameworks_env = mctx.getenv("BAZEL_MACOS_FRAMEWORKS")
    if frameworks_env:
        frameworks = [f.strip() for f in frameworks_env.split(",") if f.strip()]

    use_apple_sdk = from_archive or frameworks or experimental_include_all_sdk_libs
    if use_apple_sdk:
        _declare_apple_sdk(
            from_archive = from_archive or _DEFAULT_APPLE_SDK_ARCHIVE,
            frameworks = frameworks,
            experimental_include_all_sdk_libs = experimental_include_all_sdk_libs,
        )
    else:
        _declare_zig_libc_sdk(_DEFAULT_ZIG_LIBC_ARCHIVE)

    metadata_kwargs = {}
    if bazel_features.external_deps.extension_metadata_has_reproducible:
        metadata_kwargs["reproducible"] = True

    return mctx.extension_metadata(**metadata_kwargs)

_frameworks_tag = tag_class(
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

osx = module_extension(
    implementation = _osx_extension_impl,
    doc = "Generates an OSX sysroot with the requested set of frameworks (or a reasonable default)",
    tag_classes = {
        "from_archive": _from_archive_tag,
        "frameworks": _frameworks_tag,
        "experimental_include_all_sdk_libs": _experimental_include_all_sdk_libs_tag,
    },
)
