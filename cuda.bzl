load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:defs.bzl", "CcInfo")

def _cuda_arch_transition_impl(_settings, attr):
    if not attr.archs:
        fail("cuda_library requires a non-empty archs list")

    if len({arch: True for arch in attr.archs}) != len(attr.archs):
        fail("cuda_library requires distinct GPU architectures")

    return {
        arch: {
            "//config:nvidia_compute_capability": arch,
            "//config:cuda_device_mode": True,
        }
        for arch in attr.archs
    }

_cuda_arch_transition = transition(
    implementation = _cuda_arch_transition_impl,
    inputs = [],
    outputs = [
        "//config:nvidia_compute_capability",
        "//config:cuda_device_mode",
    ],
)

# NO RDC ONLY
def _cuda_fatbinary_impl(ctx):
    fatbin = ctx.actions.declare_file(ctx.label.name + ".fatbin")
    args = ctx.actions.args()
    args.add("--64")
    args.add(fatbin, format = "--create=%s")
    args.add("--compress-mode=size")

    fatbin_inputs = []
    for arch in sorted(ctx.split_attr.deps):
        for dep in ctx.split_attr.deps[arch]:
            # The linking context also contains transitive host libraries.
            # Only this translation unit's own device objects belong here.
            cubins = []
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                if linker_input.owner == dep.label:
                    for library in linker_input.libraries:
                        cubins.extend(library.pic_objects or [])
            if not cubins:
                fail("cuda_fatbinary requires direct PIC device objects from %s for %s" % (dep.label, arch))
            fatbin_inputs.extend(cubins)
            args.add_all(
                cubins,
                format_each = "--image3=kind=elf,sm=%s,file=%%s" % arch.removeprefix("sm_"),
            )

    if not fatbin_inputs:
        fail("cuda_fatbinary requires deps that produce at least one cubin file")

    ctx.actions.run(
        mnemonic = "CudaFatbin",
        progress_message = "Creating fatbin %s" % fatbin.short_path,
        executable = ctx.executable._fatbinary,
        inputs = fatbin_inputs,
        outputs = [fatbin],
        arguments = [args],
    )

    return [DefaultInfo(files = depset([fatbin]))]

cuda_fatbinary = rule(
    implementation = _cuda_fatbinary_impl,
    attrs = {
        "deps": attr.label_list(
            cfg = _cuda_arch_transition,
            providers = [CcInfo],
        ),
        "archs": attr.string_list(),
        "_fatbinary": attr.label(
            default = Label("//toolchain/cuda:current_fatbinary"),
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

def _dev_src(label, idx):
    return "%s__cuda_dev_%d" % (label, idx)

def _fatbin_src(label, idx):
    return "%s__fatbin_%d" % (label, idx)

def _host_src(label, idx):
    return "%s__cuda_host_%d" % (label, idx)

def cuda_library(
        name,
        srcs = [],
        hdrs = [],
        deps = [],
        defines = [],
        features = [],
        host_deps = [],
        archs = [],
        copts = [],
        **kwargs):
    """Compiles each source separately for every SM, then embeds its fatbinary.

    `deps` supplies headers to device compilation and libraries to host linking.
    `host_deps` is only available to host compilation/linking. Device code must
    be self-contained in each translation unit (no relocatable device code).
    Native cc_library attributes below retain their compilation/link semantics.
    """
    common_attrs = [
        "compatible_with",
        "exec_compatible_with",
        "exec_properties",
        "package_metadata",
        "restricted_to",
        "tags",
        "target_compatible_with",
        "testonly",
    ]
    compile_attrs = [
        "conlyopts",
        "cxxopts",
        "implementation_deps",
        "include_prefix",
        "includes",
        "local_defines",
        "nocopts",
        "strip_include_prefix",
        "textual_hdrs",
    ]
    host_attrs = ["alwayslink", "linkstatic"]
    public_attrs = [
        "additional_linker_inputs",
        "data",
        "deprecation",
        "linkopts",
        "visibility",
    ]
    for key in kwargs:
        if key not in common_attrs + compile_attrs + host_attrs + public_attrs + ["additional_compiler_inputs"]:
            fail("cuda_library does not support attribute %r" % key)

    common_kwargs = {key: kwargs[key] for key in common_attrs if key in kwargs}
    compile_kwargs = dict(common_kwargs)
    compile_kwargs.update({key: kwargs[key] for key in compile_attrs if key in kwargs})
    device_kwargs = dict(compile_kwargs)
    device_kwargs["tags"] = kwargs.get("tags", []) + ["manual"]
    host_kwargs = dict(compile_kwargs)
    host_kwargs.update({key: kwargs[key] for key in host_attrs if key in kwargs})
    compiler_inputs = kwargs.get("additional_compiler_inputs", [])

    host_unit_deps = []
    for idx in range(len(srcs)):
        src = srcs[idx]
        dev_src_target = _dev_src(name, idx)
        fatbin_src_target = _fatbin_src(name, idx)
        host_src_target = _host_src(name, idx)

        cc_library(
            name = dev_src_target,
            srcs = [src],
            hdrs = hdrs,
            copts = copts + [
                # cute and other specialize is_reference<>
                "-Wno-error=invalid-specialization",
            ],
            defines = defines,
            features = features,
            additional_compiler_inputs = compiler_inputs,
            deps = deps,
            # This target only makes sense to be used within the transition
            visibility = ["//visibility:private"],
            **device_kwargs
        )

        # Fatbin per source unit (across all requested architectures).
        cuda_fatbinary(
            name = fatbin_src_target,
            deps = [dev_src_target],
            archs = archs,
            visibility = ["//visibility:private"],
            **common_kwargs
        )

        cc_library(
            name = host_src_target,
            srcs = [src],
            hdrs = hdrs,
            defines = defines,
            deps = deps + host_deps,
            features = features,
            copts = copts + [
                "--cuda-path=$(location {})".format(Label("//toolchain/cuda:current_cuda_path")),
                "--offload-host-only",
                "-Xclang",
                "-fcuda-include-gpubinary",
                "-Xclang",
                "$(execpath :%s)" % fatbin_src_target,
            ] + [
                "-Wno-error=invalid-specialization",
            ],
            additional_compiler_inputs = compiler_inputs + [
                Label("//toolchain/cuda:current_cuda_path"),
                fatbin_src_target,
            ],
            visibility = ["//visibility:private"],
            **host_kwargs
        )

        host_unit_deps.append(host_src_target)

    # Public library aggregates all per-source host objects.
    cc_library(
        name = name,
        hdrs = hdrs,
        defines = defines,
        features = features,
        deps = host_unit_deps + deps + host_deps,
        **kwargs
    )
