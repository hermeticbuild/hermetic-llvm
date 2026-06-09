GCC_VERSIONS = [
    "17.0.0",
    "16.1.0",
    "15.2.0",
    "15.1.0",
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
