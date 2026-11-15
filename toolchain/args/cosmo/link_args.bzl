"""Link argument groups for the two Cosmopolitan target architectures."""

load("@rules_cc//cc/toolchains:args.bzl", "cc_args")

def cosmo_link_args(cpu, common_page_size):
    """Declares the released CRT, linker script, and BFD arguments."""
    sdk = "@cosmopolitan_sdk//:"
    bfd = sdk + cpu + "_bfd"
    args = [
        "-static",
        "-nostdlib",
        "-Wl,-z,noexecstack,-z,norelro,--gc-sections",
        "-Wl,-z,max-page-size=16384",
        "-Wl,-z,common-page-size=" + str(common_page_size),
        "-Wl,-T,{script}",
        "-L{libs}",
    ]
    libs = "@cosmopolitan_sdk//:" + cpu + "_libs"
    format = {
        "crt": sdk + cpu + "_crt",
        "libs": libs,
        "script": sdk + cpu + "_script",
    }
    if cpu == "x86_64":
        args.append("{ape}")
        format["ape"] = sdk + cpu + "_ape"

    cc_args(
        name = cpu + "_link",
        actions = ["@rules_cc//cc/toolchains/actions:link_executable_actions"],
        args = args + ["{crt}"],
        data = [libs],
        format = format,
    )

    cc_args(
        name = cpu + "_link_env",
        actions = ["@rules_cc//cc/toolchains/actions:link_executable_actions"],
        data = [bfd],
        env = {
            "COSMO_BFD": "{bfd}",
            "COSMO_LINK_OUTPUT": "{output_execpath}",
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
