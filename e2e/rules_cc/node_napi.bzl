load("@rules_cc//cc:cc_binary.bzl", "cc_binary")

def cc_napi_library(name, deps = [], defines = [], linkopts = [], visibility = None, **kwargs):
    dylib_name = "lib" + name + ".so"

    cc_binary(
        name = dylib_name,
        defines = defines + [
            "V8_IMMINENT_DEPRECATION_WARNINGS=1",
        ],
        deps = deps + [
            "@rules_nodejs//nodejs/headers:current_node_cc_headers",
        ],
        linkopts = linkopts + select({
            # V8 symbols come from the node binary loading this addon.
            "@platforms//os:osx": [
                "-undefined",
                "dynamic_lookup",
            ],
            "//conditions:default": [],
        }),
        linkshared = True,
        **kwargs
    )

    native.genrule(
        name = "gen_" + name,
        srcs = [":" + dylib_name],
        outs = [name],
        cmd = "cp $< $@",
        visibility = visibility,
    )
