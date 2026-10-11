def configure_builder_for_runtimes(builder, runtime_stage, linkmode = "static", sanitizers = False, inherit_asan = False, inherit_msan = False):
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

    if sanitizers == False:
        builder.set(Label("//config:ubsan"), False)
        builder.set(Label("//config:cfi"), False)
        builder.set(Label("//config:dfsan"), False)
        builder.set(Label("//config:nsan"), False)
        builder.set(Label("//config:safestack"), False)
        builder.set(Label("//config:rtsan"), False)
        builder.set(Label("//config:tysan"), False)
        builder.set(Label("//config:tsan"), False)
        builder.set(Label("//config:lsan"), False)
        builder.set(Label("//config:xray"), False)
        builder.set(Label("//config:fuzzer"), False)
        builder.set(Label("//config:profile"), False)
        builder.set(Label("//config:host_ubsan"), False)
        builder.set(Label("//config:host_cfi"), False)
        builder.set(Label("//config:host_dfsan"), False)
        builder.set(Label("//config:host_nsan"), False)
        builder.set(Label("//config:host_safestack"), False)
        builder.set(Label("//config:host_rtsan"), False)
        builder.set(Label("//config:host_tysan"), False)
        builder.set(Label("//config:host_tsan"), False)
        builder.set(Label("//config:host_lsan"), False)
        builder.set(Label("//config:host_xray"), False)
        builder.set(Label("//config:host_fuzzer"), False)
        builder.set(Label("//config:host_profile"), False)

        if not inherit_asan:
            builder.set(Label("//config:asan"), False)
            builder.set(Label("//config:host_asan"), False)

        if not inherit_msan:
            builder.set(Label("//config:msan"), False)
            builder.set(Label("//config:host_msan"), False)

    return builder
