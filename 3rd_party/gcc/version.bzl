GCC_VERSIONS = [
    "17.0.0",
    "16.1.0",
    "15.2.0",
    "15.1.0",
    "14.3.0",
    "14.2.0",
    "13.4.0",
    "13.3.0",
    "13.2.0",
    "13.1.0",
]

DEFAULT_GCC_VERSION = "17.0.0"

GCC_RELEASES = {
    "17.0.0": {
        "commit": "2bfd402f8569511901ec8fe7628f57471e6d240a",
        "sha256": "dc033fdfd79caf199113446af6d082004534437b6ebd276f9732815d86cbe723",
    },
    "16.1.0": {
        "commit": "6afcc4f6da931eb93f3ab001a0dd9650ea71d1ea",
        "sha256": "b62f8feee8f9f6e3c9bb60e09546c869dacd2b1e2948a2da2c610ce76a3e5e89",
    },
    "15.1.0": {
        "commit": "1b306039ac49f8ad91ca71d3de3150a3c9fa792a",
        "sha256": "b45e06e72a265b129f0f68fc81b7be06c931e5ff7c2d47bafcd45c573eda96ad",
    },
    "15.2.0": {
        "commit": "5115c7e447fc07457443df874bf57840e8316d5f",
        "sha256": "0a1cfcef7d3903f706c94ceba9f49a08bf3acd8ce5258270f7f3016290f7c4ee",
    },
    "14.2.0": {
        "commit": "04696df09633baf97cdbbdd6e9929b9d472161d3",
        "sha256": "bc304fe24d9c046588d6336a283325eb86c85b88699111ae9cccc08ca16fbc66",
    },
    "14.3.0": {
        "commit": "c9cd41fba9ebd288c4f101e4b99da934bcb96a11",
        "sha256": "e15cb7bdf3f0cbda46d3bd58082abb5cd9bbbb4749c03292a19cf91c285555e1",
    },
    "13.1.0": {
        "commit": "cc035c5d8672f87dc8c2756d9f8367903aa72d93",
        "sha256": "decd4061fa41b28073c9e7a7b2c1b294c413f3b6efd0fff5552c77dbe40deaa8",
    },
    "13.2.0": {
        "commit": "c891d8dc23e1a46ad9f3e757d09e57b500d40044",
        "sha256": "47478252fe8b890a43396707349bfe4a013426dc63d43dd14a0c5dff2a6fe952",
    },
    "13.3.0": {
        "commit": "b71f1de6e9cf7181a288c0f39f9b1ef6580cf5c8",
        "sha256": "54e834fe573948905c934a494ae503d90b08b5607f8f1650ffddf052051b5339",
    },
    "13.4.0": {
        "commit": "99677969d463d75a562f94460ea75e9f6a016b4f",
        "sha256": "2a061f0d2afe337127d50f607644adfa0f4e1c019c829ade3643f1afb6702191",
    },
}

GCC_VERSION = DEFAULT_GCC_VERSION
GCC_COMMIT = GCC_RELEASES[DEFAULT_GCC_VERSION]["commit"]
GCC_SHA256 = GCC_RELEASES[DEFAULT_GCC_VERSION]["sha256"]

def gcc_repo_name(version):
    return "gcc_" + version.replace(".", "_")

def gcc_repository_label(version, target):
    return "@gcc//:{}/{}".format(gcc_repo_name(version), target)

def gcc_config_toolexeclibdir_target(version):
    if gcc_version_at_least_for(version, "10.0.0"):
        return "config/toolexeclibdir.m4"
    return "gcc_config_toolexeclibdir_m4"

def libstdcxx_constraint_value(version):
    return "libstdcxx." + version

def libstdcxx_constraint_label(version):
    return "@llvm//constraints/cxxstdlib:" + libstdcxx_constraint_value(version)

def gcc_target_suffix(version):
    return "gcc_" + version.replace(".", "_")

def _version_tuple(version):
    parts = version.split(".")
    values = [int(part) for part in parts]
    if len(values) == 1:
        values.extend([0, 0])
    elif len(values) == 2:
        values.append(0)
    return values

def _compare_versions(lhs, rhs):
    lhs_values = _version_tuple(lhs)
    rhs_values = _version_tuple(rhs)
    for i in range(3):
        if lhs_values[i] < rhs_values[i]:
            return -1
        if lhs_values[i] > rhs_values[i]:
            return 1
    return 0

def gcc_version_at_least_for(gcc_version, version):
    return _compare_versions(gcc_version, version) >= 0

def gcc_version_less_than_for(gcc_version, version):
    return _compare_versions(gcc_version, version) < 0

def gcc_version_at_least(version):
    return gcc_version_at_least_for(GCC_VERSION, version)

def gcc_version_less_than(version):
    return gcc_version_less_than_for(GCC_VERSION, version)

def select_for_gcc_version(values):
    choices = {
        libstdcxx_constraint_label(version): values[version]
        for version in GCC_VERSIONS
    }
    choices["//conditions:default"] = values[DEFAULT_GCC_VERSION]
    return select(choices)

def select_gcc_version_at_least(version, then, otherwise):
    return select_for_gcc_version({
        gcc_version: then if gcc_version_at_least_for(gcc_version, version) else otherwise
        for gcc_version in GCC_VERSIONS
    })

def libstdcxx_has_atomic_builtins_define(version):
    return gcc_version_less_than_for(version, "16.0.0")

def libstdcxx_has_posix_semaphore_check(version):
    return gcc_version_less_than_for(version, "16.0.0")

def libstdcxx_has_debugging_checks(version):
    return gcc_version_at_least_for(version, "16.0.0")

def libstdcxx_has_stdio_locking_checks(version):
    return gcc_version_at_least_for(version, "16.0.0")

def libstdcxx_has_networking_o_nonblock_check(version):
    return (gcc_version_at_least_for(version, "13.4.0") and gcc_version_less_than_for(version, "14.0.0")) or gcc_version_at_least_for(version, "14.3.0")

def libstdcxx_has_struct_tm_tm_zone_check(version):
    return gcc_version_at_least_for(version, "15.0.0")

def libstdcxx_has_c99_cxx11_detail_checks(version):
    return gcc_version_at_least_for(version, "14.0.0")

def libstdcxx_has_fseeko_ftello_check(version):
    return gcc_version_at_least_for(version, "13.2.0")

def libstdcxx_has_filesystem_chdir_chmod_getcwd_mkdir_checks(version):
    return gcc_version_at_least_for(version, "13.3.0")

def libstdcxx_has_filesystem_copy_file_range_check(version):
    return gcc_version_at_least_for(version, "14.0.0")

def libstdcxx_has_text_encoding_checks(version):
    return gcc_version_at_least_for(version, "14.0.0")

def libstdcxx_has_alignas_init_priority_checks(version):
    return gcc_version_at_least_for(version, "13.2.0")
