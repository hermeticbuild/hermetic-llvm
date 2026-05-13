def _rbe_platform_repo_impl(rctx):
    arch = rctx.attr.arch
    if arch == "host":
        arch = rctx.os.arch

    if arch in ["x86_64", "amd64"]:
        cpu = "x86_64"
        exec_arch = "amd64"
    elif arch in ["aarch64", "arm64"]:
        cpu = "aarch64"
        exec_arch = "arm64"
    else:
        fail("Unsupported host arch for rbe platform: {}".format(arch))

    rctx.file("BUILD.bazel", _rbe_platform_block(
        name = "rbe_platform",
        cpu = cpu,
        arch = exec_arch,
    ))

def _rbe_platform_block(name, cpu, arch):
    return """\
platform(
    name = "{name}",
    constraint_values = [
        "@platforms//cpu:{cpu}",
        "@platforms//os:linux",
        "@llvm//constraints/libc:gnu.2.28",
    ],
    exec_properties = {{
        "container-image": "docker://ubuntu:22.04",
        "Arch": "{arch}",
        "OSFamily": "Linux",
    }},
    visibility = ["//visibility:public"],
)
""".format(
        name = name,
        cpu = cpu,
        arch = arch,
    )

rbe_platform_repository = repository_rule(
    implementation = _rbe_platform_repo_impl,
    attrs = {
        "arch": attr.string(
            default = "x86_64",
            values = ["host", "x86_64", "amd64", "aarch64", "arm64"],
            doc = "Remote execution architecture. Use 'host' to match the local host architecture.",
        ),
    },
    doc = "Sets up the single platform used for remote builds.",
)
