"""Link argument groups for the two Cosmopolitan target architectures."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")

def cosmo_link_args(cpu):
    """Declares the CRT, linker script, and GNU BFD arguments."""
    bfd = "@cosmopolitan_sdk//:" + cpu + "_bfd"
    common_page_size = 4096 if cpu == "x86_64" else 16384
    args = [
        "-static",
        "-nostdlib",
        "-Wl,-z,noexecstack,-z,norelro,--gc-sections",
        "-Wl,-z,max-page-size=16384",
        "-Wl,-z,common-page-size=" + str(common_page_size),
        "-Wl,-T,{script}",
        "-L{libs}",
    ]
    artifacts = "@llvm//runtimes/cosmo:" + cpu
    format = {
        "crt": artifacts + "_crt",
        "libs": artifacts + "_libs",
        "script": artifacts + "_script",
    }
    if cpu == "x86_64":
        args.append("{ape}")
        format["ape"] = artifacts + "_ape"

    cc_args(
        name = cpu + "_link",
        actions = ["@rules_cc//cc/toolchains/actions:link_executable_actions"],
        args = args + ["{crt}"],
        data = format.values(),
        format = format,
    )

    cc_args(
        name = cpu + "_link_env",
        actions = ["@rules_cc//cc/toolchains/actions:link_executable_actions"],
        data = [bfd],
        env = {
            "COSMO_BFD": "{bfd}",
            "COSMO_FIXUP_OUTPUT": "{output_execpath}",
        } | select({
            "//config:nostdlibxx_enabled": {},
            "//conditions:default": {"COSMO_LIBCXX": "1"},
        }),
        format = {
            "bfd": bfd,
            "output_execpath": "@rules_cc//cc/toolchains/variables:output_execpath",
        },
        requires_not_none = "@rules_cc//cc/toolchains/variables:output_execpath",
    )
