"""A test alias that selects the static MSVC CRT for its dependency graph."""

load("@with_cfg.bzl", "with_cfg")

static_crt_alias, _static_crt_alias_internal = with_cfg(native.alias).extend(
    "features",
    ["-dynamic_link_msvcrt", "static_link_msvcrt"],
).build()
