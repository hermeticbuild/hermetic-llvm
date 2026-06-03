load("@bazel_features//:features.bzl", "bazel_features")

def validate_static_library_compatible():
    if bazel_features.cc.supports_starlarkified_toolchains:
        return []

    # Bazel 8 does not propagate custom tool env on validate_static_library. Keep
    # this validator integration coverage on Bazel 9+, where the tool env works.
    return ["@platforms//:incompatible"]
