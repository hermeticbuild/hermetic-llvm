"""Packages APE binaries with loaders from the Cosmopolitan source release."""

load("//:apify.bzl", "apify_binary")

def apify_with_source_loaders(name, **kwargs):
    """Passes the source-built ELF loaders and Apple Silicon loader to apelink."""
    apify_binary(
        name = name,
        aarch64_loader = Label("//prebuilt/cosmo:ape-aarch64.elf"),
        macos_aarch64_loader_source = Label("//prebuilt/cosmo:ape-m1.c"),
        x86_64_loader = Label("//prebuilt/cosmo:ape-x86_64.elf"),
        **kwargs
    )
