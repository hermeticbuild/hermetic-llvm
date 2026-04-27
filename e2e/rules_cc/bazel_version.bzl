load("@bazel_features//:features.bzl", "bazel_features")

def validate_static_library_compatible():
    if bazel_features.cc.supports_starlarkified_toolchains:
        return []

    # Bazel 8 drops `cc_args(env = ...)` on validate_static_library. Keep this
    # validator integration coverage on Bazel 9+, where the tool env is propagated.
    return ["@platforms//:incompatible"]
