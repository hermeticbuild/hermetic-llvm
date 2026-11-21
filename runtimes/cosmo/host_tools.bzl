"""Selects the native loader used to run Cosmopolitan SDK tools."""

APE_LOADERS = {
    ("linux", "aarch64"): Label("@cosmopolitan_sdk//:linux_aarch64_loader"),
    ("linux", "x86_64"): Label("@cosmopolitan_sdk//:linux_x86_64_loader"),
    ("macos", "aarch64"): Label("//runtimes/cosmo:ape-macos-arm64"),
    ("macos", "x86_64"): Label("@cosmopolitan_sdk//:macos_x86_64_loader"),
}

APE_LOADER = select({
    "//platforms/config:{}_{}".format(os, cpu): loader
    for (os, cpu), loader in APE_LOADERS.items()
})
