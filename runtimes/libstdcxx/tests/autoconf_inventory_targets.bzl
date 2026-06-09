load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load(
    "//3rd_party/gcc:version.bzl",
    "GCC_VERSIONS",
    "gcc_repository_label",
    "gcc_target_suffix",
    "select_for_gcc_version",
)

_AUTOCONF_AUDIT_BASE_DATA = [
    "//runtimes/libstdcxx/docs:config_define_status.txt",
    "//runtimes/libstdcxx/docs:config_macro_status.txt",
]

_AUTOCONF_MODEL_DATA = [
    "//runtimes/libstdcxx:acinclude.m4.bzl",
    "//runtimes/libstdcxx:configure.ac.bzl",
    "//runtimes/libstdcxx:crossconfig.m4.bzl",
    "//runtimes/libstdcxx:gcc_config_checks.bzl",
    "//runtimes/libstdcxx:linkage.m4.bzl",
    "//runtimes/libstdcxx:target_config.bzl",
    "//runtimes/libstdcxx:libstdcxx_config_h.bzl",
    "//runtimes/libstdcxx:libstdcxx_cxxconfig_header.bzl",
    "//runtimes/libstdcxx:libstdcxx_gthr_headers.bzl",
    "//runtimes/libstdcxx:libstdcxx_largefile_config_header.bzl",
    "//runtimes/libstdcxx/autoconf:autoconf_config.bzl",
    "//runtimes/libstdcxx/autoconf:autoconf_hdr.bzl",
    "//runtimes/libstdcxx/autoconf:cc_configure_probe.bzl",
    "//runtimes/libstdcxx/autoconf:checks.bzl",
    "//runtimes/libstdcxx/autoconf:providers.bzl",
    "//runtimes/libstdcxx:libstdcxx_symbols_version_script.bzl",
]

_AUTOCONF_MODEL_ENV = {
    "ACINCLUDE_CHECKS": "$(rootpath //runtimes/libstdcxx:acinclude.m4.bzl)",
    "AUTOCONF_CONFIG": "$(rootpath //runtimes/libstdcxx/autoconf:autoconf_config.bzl)",
    "AUTOCONF_HDR": "$(rootpath //runtimes/libstdcxx/autoconf:autoconf_hdr.bzl)",
    "CC_CONFIGURE_PROBE": "$(rootpath //runtimes/libstdcxx/autoconf:cc_configure_probe.bzl)",
    "CHECKS": "$(rootpath //runtimes/libstdcxx/autoconf:checks.bzl)",
    "CONFIGURE_AC_CHECKS": "$(rootpath //runtimes/libstdcxx:configure.ac.bzl)",
    "CROSSCONFIG_CHECKS": "$(rootpath //runtimes/libstdcxx:crossconfig.m4.bzl)",
    "CXXCONFIG_HEADER": "$(rootpath //runtimes/libstdcxx:libstdcxx_cxxconfig_header.bzl)",
    "GCC_CONFIG_CHECKS": "$(rootpath //runtimes/libstdcxx:gcc_config_checks.bzl)",
    "GTHR_HEADERS": "$(rootpath //runtimes/libstdcxx:libstdcxx_gthr_headers.bzl)",
    "LARGEFILE_CONFIG_HEADER": "$(rootpath //runtimes/libstdcxx:libstdcxx_largefile_config_header.bzl)",
    "LIBSTDCXX_CONFIG_H": "$(rootpath //runtimes/libstdcxx:libstdcxx_config_h.bzl)",
    "LINKAGE_CHECKS": "$(rootpath //runtimes/libstdcxx:linkage.m4.bzl)",
    "PROVIDERS": "$(rootpath //runtimes/libstdcxx/autoconf:providers.bzl)",
    "TARGET_CONFIG": "$(rootpath //runtimes/libstdcxx:target_config.bzl)",
    "VERSION_SCRIPT": "$(rootpath //runtimes/libstdcxx:libstdcxx_symbols_version_script.bzl)",
}

_AUTOCONF_DOC_DATA = [
    "//runtimes/libstdcxx/docs:autoconf.README.md",
    "//runtimes/libstdcxx/docs:autoconf.checks.md",
    "//runtimes/libstdcxx/docs:autoconf.usage.md",
]

_AUTOCONF_DOC_ENV = {
    "AUTOCONF_CHECKS": "$(rootpath //runtimes/libstdcxx/docs:autoconf.checks.md)",
    "AUTOCONF_README": "$(rootpath //runtimes/libstdcxx/docs:autoconf.README.md)",
    "AUTOCONF_USAGE": "$(rootpath //runtimes/libstdcxx/docs:autoconf.usage.md)",
}

def _rootpath(label):
    return "$(rootpath {})".format(label)

def _gcc_audit_inputs(version):
    return gcc_repository_label(version, "libstdcxx_autoconf_audit_inputs")

def _gcc_audit_path(version, path):
    return "{}/{}".format(_rootpath(_gcc_audit_inputs(version)), path)

def _gcc_audit_data(version):
    return (
        _AUTOCONF_AUDIT_BASE_DATA +
        [_gcc_audit_inputs(version)]
    )

def _gcc_audit_env(version):
    return {
        "GCC_ACINCLUDE": _gcc_audit_path(version, "libstdc++-v3/acinclude.m4"),
        "GCC_CONFIG_ACX": _gcc_audit_path(version, "config/acx.m4"),
        "GCC_CONFIG_CET": _gcc_audit_path(version, "config/cet.m4"),
        "GCC_CONFIG_FUTEX": _gcc_audit_path(version, "config/futex.m4"),
        "GCC_CONFIG_GCXXFILT": _gcc_audit_path(version, "config/gc++filt.m4"),
        "GCC_CONFIG_GTHR": _gcc_audit_path(version, "config/gthr.m4"),
        "GCC_CONFIG_HWCAPS": _gcc_audit_path(version, "config/hwcaps.m4"),
        "GCC_CONFIG_ICONV": _gcc_audit_path(version, "config/iconv.m4"),
        "GCC_CONFIG_LTHOSTFLAGS": _gcc_audit_path(version, "config/lthostflags.m4"),
        "GCC_CONFIG_MULTI": _gcc_audit_path(version, "config/multi.m4"),
        "GCC_CONFIG_NO_EXECUTABLES": _gcc_audit_path(version, "config/no-executables.m4"),
        "GCC_CONFIG_TLS": _gcc_audit_path(version, "config/tls.m4"),
        "GCC_CONFIG_TOOLEXECLIBDIR": _gcc_audit_path(version, "config/toolexeclibdir.m4"),
        "GCC_CONFIG_UNWIND_IPINFO": _gcc_audit_path(version, "config/unwind_ipinfo.m4"),
        "GCC_CONFIGURE_AC": _gcc_audit_path(version, "libstdc++-v3/configure.ac"),
        "GCC_CONFIGURE_HOST": _gcc_audit_path(version, "libstdc++-v3/configure.host"),
        "GCC_CROSSCONFIG": _gcc_audit_path(version, "libstdc++-v3/crossconfig.m4"),
        "GCC_LINKAGE": _gcc_audit_path(version, "libstdc++-v3/linkage.m4"),
        "GCC_VERSION": version,
        "MACRO_STATUS_FILE": "$(rootpath //runtimes/libstdcxx/docs:config_macro_status.txt)",
        "STATUS_FILE": "$(rootpath //runtimes/libstdcxx/docs:config_define_status.txt)",
    }

def declare_autoconf_inventory_targets():
    for version in GCC_VERSIONS:
        suffix = gcc_target_suffix(version)
        audit_data = _gcc_audit_data(version)
        audit_env = _gcc_audit_env(version)

        sh_test(
            name = "config_define_audit_test_" + suffix,
            srcs = ["autoconf_inventory.sh"],
            args = ["check-status"],
            data = audit_data + _AUTOCONF_MODEL_DATA,
            env = dict(audit_env.items() + _AUTOCONF_MODEL_ENV.items()),
        )

        sh_test(
            name = "autoconf_inventory_test_" + suffix,
            srcs = ["autoconf_inventory.sh"],
            args = ["check-docs"],
            data = audit_data + _AUTOCONF_DOC_DATA,
            env = dict(audit_env.items() + _AUTOCONF_DOC_ENV.items()),
        )

        sh_binary(
            name = "autoconf_inventory_" + suffix,
            srcs = ["autoconf_inventory.sh"],
            data = audit_data + _AUTOCONF_MODEL_DATA + _AUTOCONF_DOC_DATA,
            env = dict(
                audit_env.items() +
                _AUTOCONF_MODEL_ENV.items() +
                _AUTOCONF_DOC_ENV.items(),
            ),
        )

    native.test_suite(
        name = "config_define_audit_test",
        tests = [
            ":config_define_audit_test_" + gcc_target_suffix(version)
            for version in GCC_VERSIONS
        ],
    )

    native.test_suite(
        name = "autoconf_inventory_test",
        tests = [
            ":autoconf_inventory_test_" + gcc_target_suffix(version)
            for version in GCC_VERSIONS
        ],
    )

    native.alias(
        name = "autoconf_inventory",
        actual = select_for_gcc_version({
            version: ":autoconf_inventory_" + gcc_target_suffix(version)
            for version in GCC_VERSIONS
        }),
    )
