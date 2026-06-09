load("//3rd_party/gcc:version.bzl", "DEFAULT_GCC_VERSION", "GCC_VERSIONS", "gcc_repo_name", "libstdcxx_constraint_label")

def make_select_gcc_repository_target(bazel_target):
    choices = {
        libstdcxx_constraint_label(version): "@{}//:{}".format(gcc_repo_name(version), bazel_target)
        for version in GCC_VERSIONS
    }
    choices["//conditions:default"] = "@{}//:{}".format(gcc_repo_name(DEFAULT_GCC_VERSION), bazel_target)
    return select(choices)
