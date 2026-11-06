"""An alias that builds its target with the external_include_paths feature."""

load("@with_cfg.bzl", "with_cfg")

external_include_paths_alias, _external_include_paths_alias_internal = with_cfg(native.alias).extend(
    "features",
    ["external_include_paths"],
).build()
