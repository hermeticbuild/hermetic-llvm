load("//config:defs.bzl", "INSTRUMENTATION_SETTINGS")

# Inherit only the sanitizer settings supported by the C++ standard library
# runtimes. The caller still decides whether to enable any of them.
CXX_STDLIB_INHERITED_SANITIZERS = ["asan", "msan"]

def configure_builder_for_runtimes(builder, runtime_stage, linkmode = "static", inherit_sanitizers = []):
    # The problem is that compiler-rt and start libs can only be compiled with
    # a specific set of flags and compilation mode. It is not safe to let the user
    # interfere with them using default command line flags.
    # TODO: Expose a build setting to extend those flags.
    builder.set("copt", [])
    builder.set("cxxopt", [])
    builder.set("conlyopt", [])
    builder.set("linkopt", [])
    builder.set("host_copt", [])
    builder.set("host_cxxopt", [])
    builder.set("host_conlyopt", [])
    builder.set("host_linkopt", [])

    # Release policy is expressed through compiler-personality features rather
    # than user compile options. Reset it at the same runtime boundary as the
    # options above: each runtime owns its exception, RTTI, and frame-pointer
    # requirements independently from the final LLVM product.
    builder.extend("features", [
        "-no_exceptions",
        "-no_rtti",
        "-omit_frame_pointer",
    ])

    # We are compiling runtimes without any kind of other dependencies.
    builder.set(
        Label("//toolchain:runtime_stage"),
        runtime_stage,
    )

    builder.set(
        Label("//runtimes:linkmode"),
        linkmode,
    )

    for sanitizer in inherit_sanitizers:
        if sanitizer not in INSTRUMENTATION_SETTINGS:
            fail("Unknown sanitizer to inherit: " + sanitizer)

    for setting in INSTRUMENTATION_SETTINGS:
        if setting not in inherit_sanitizers:
            builder.set(Label("//config:" + setting), False)
            builder.set(Label("//config:host_" + setting), False)

    return builder
