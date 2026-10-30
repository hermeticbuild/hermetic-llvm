# TODO(https://github.com/bazelbuild/bazel/issues/32020): Use a source annotation
# when Bazel exposes this context type.
def _rbe_platform_repo_impl(rctx):
    # type: (repository_ctx) -> None
    arch = rctx.os.arch
    if arch in ["x86_64", "amd64"]:
        host_platform = "rbe_linux_x86_64"
    elif arch in ["aarch64", "arm64"]:
        host_platform = "rbe_linux_aarch64"
    else:
        fail("Unsupported host arch for rbe platform: {}".format(arch))

    platforms = []
    for cpu, exec_arch in [("x86_64", "amd64"), ("aarch64", "arm64")]:
        for suffix, libc in [("", "gnu.2.28"), ("_musl", "musl")]:
            platforms.append("""\
platform(
    name = "rbe_linux_{cpu}{suffix}",
    constraint_values = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:linux",
        "@llvm//constraints/libc:{libc}",
    ],
    exec_properties = {{
        "container-image": "docker://ubuntu:22.04",
        "Arch": "{exec_arch}",
        "OSFamily": "Linux",
    }},
    visibility = ["//visibility:public"],
)
""".format(cpu = cpu, exec_arch = exec_arch, libc = libc, suffix = suffix))

    platforms.append("""\
alias(
    name = "rbe_platform",
    actual = ":{host_platform}",
    visibility = ["//visibility:public"],
)
""".format(host_platform = host_platform))

    rctx.file("BUILD.bazel", "\n".join(platforms))

rbe_platform_repository = repository_rule(
    implementation = _rbe_platform_repo_impl,
    doc = "Sets up AMD64 and ARM64 Linux platforms for remote builds.",
)
