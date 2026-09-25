load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_cc//cc:find_cc_toolchain.bzl", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")

_CudaCompilationInfo = provider(fields = ["units"])
_CudaHostObjectsInfo = provider(fields = ["symbols"])
_CudaImagesInfo = provider(fields = ["images"])

def _cuda_compilation_impl(target, ctx):
    # Use actual compile inputs/outputs, never object basenames or list order.
    # File.short_path excludes the split configuration's output directory.
    sources = {}
    for dep in ctx.rule.attr.srcs:
        for source in dep[DefaultInfo].files.to_list():
            if source.extension != "cu" or source.is_directory:
                fail("CUDA compilation requires individual .cu files: %s" % source.path)
            key = str(source.owner) + ":" + source.short_path
            if source in sources:
                fail("Duplicate CUDA source: %s" % source.path)
            sources[source] = key
    units = {key: struct(objects = [], pic_objects = []) for key in sources.values()}
    objects = {}
    for linker_input in target[CcInfo].linking_context.linker_inputs.to_list():
        if linker_input.owner == target.label:
            for library in linker_input.libraries:
                for obj in library.objects or []:
                    objects[obj] = False
                for obj in library.pic_objects or []:
                    objects[obj] = True
    seen = {}
    for action in target.actions:
        outputs = [obj for obj in action.outputs.to_list() if obj in objects]
        if not outputs:
            continue
        if action.mnemonic != "CppCompile":
            fail("CUDA requires native CppCompile objects from %s" % target.label)
        matches = [source for source in action.inputs.to_list() if source in sources]
        if len(matches) != 1:
            fail("Ambiguous CUDA source mapping for %s: %s" % (outputs, matches))
        unit = units[sources[matches[0]]]
        for obj in outputs:
            if obj in seen:
                fail("Duplicate CUDA compile output: %s" % obj.path)
            seen[obj] = True
            (unit.pic_objects if objects[obj] else unit.objects).append(obj)
    if len(seen) != len(objects):
        fail("Incomplete CUDA compile mapping for %s" % target.label)
    for key, unit in units.items():
        if not unit.objects and not unit.pic_objects:
            fail("CUDA source has no native compile output: %s" % key)
    return [_CudaCompilationInfo(units = units)]

_cuda_compilation = aspect(implementation = _cuda_compilation_impl)

# An injective encoding, rather than a short hash or punctuation replacement.
# Include the configuration so independently configured copies cannot alias.
_SYMBOL_CHARS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~"
_HEX = "0123456789abcdef"

def _payload_symbol(ctx, source):
    identity = str(ctx.label) + ":" + ctx.bin_dir.path + ":" + source
    encoded = []
    for char in identity.elems():
        index = _SYMBOL_CHARS.find(char)
        if index < 0:
            fail("CUDA payload identifiers require ASCII labels: %s" % ctx.label)
        encoded.append(_HEX[index // 16] + _HEX[index % 16])
    return "__cuda_payload_" + "".join(encoded)

def _cuda_host_objects_impl(ctx):
    raw = ctx.attr.raw
    symbols = {}
    outputs = []
    raw_pic_objects = []
    for source, unit in raw[_CudaCompilationInfo].units.items():
        symbol = _payload_symbol(ctx, source)
        symbols[source] = symbol
        raw_pic_objects.extend(unit.pic_objects)

        # Precompiled PIC objects work in static and shared links. Export only
        # one variant per TU to avoid duplicate definitions under alwayslink.
        objects = unit.pic_objects or unit.objects
        if len(objects) != 1:
            fail("Expected one native host object for %s" % source)
        obj = objects[0]
        suffix = ".pic.o" if unit.pic_objects else ".nopic.o"
        out = ctx.actions.declare_file("%s/%d%s" % (ctx.label.name, len(outputs), suffix))
        args = ctx.actions.args()
        args.add_all([obj, out, symbol])
        ctx.actions.run(
            mnemonic = "CudaHostRedirect",
            executable = ctx.executable._redirect,
            inputs = [obj],
            outputs = [out],
            arguments = [args],
        )
        outputs.append(out)
    if not outputs:
        fail("CUDA host redirection requires direct native objects from %s (LTO is unsupported)" % raw.label)
    return [
        DefaultInfo(files = depset(outputs)),
        # Forward headers/defines, never the unmodified objects or archives.
        CcInfo(compilation_context = raw[CcInfo].compilation_context),
        _CudaHostObjectsInfo(symbols = symbols),
        OutputGroupInfo(raw_pic_objects = depset(raw_pic_objects)),
    ]

_cuda_host_objects = rule(
    implementation = _cuda_host_objects_impl,
    attrs = {
        "raw": attr.label(mandatory = True, providers = [CcInfo], aspects = [_cuda_compilation]),
        "_redirect": attr.label(
            default = Label("//tools/internal:cuda-redirect"),
            executable = True,
            cfg = "exec",
        ),
    },
)

def _cuda_payload_impl(ctx):
    symbols = ctx.attr.host[_CudaHostObjectsInfo].symbols
    images = ctx.attr.images[_CudaImagesInfo].images
    if sorted(symbols) != sorted(images):
        fail("Host/device CUDA sources differ: %s vs %s" % (sorted(symbols), sorted(images)))
    toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    objects = []
    for index, source in enumerate(sorted(symbols)):
        symbol = symbols[source]
        assembly = ctx.actions.declare_file("%s/%d.s" % (ctx.label.name, index))

        # .incbin does not participate in header input discovery. Declare only
        # this TU's image so embedding remains independently cacheable.
        image = images[source].path.replace("\\", "\\\\").replace("\"", "\\\"")
        ctx.actions.write(assembly, """.section .nv_fatbin,"a",%progbits
.balign 8
.globl {symbol}
.hidden {symbol}
.type {symbol},%object
{symbol}:
.incbin "{image}"
.size {symbol}, .-{symbol}
.section .note.GNU-stack,"",%progbits
""".format(symbol = symbol, image = image))
        _, compiled = cc_common.compile(
            actions = ctx.actions,
            cc_toolchain = toolchain,
            feature_configuration = feature_configuration,
            name = "%s/%d" % (ctx.label.name, index),
            srcs = [assembly],
            additional_inputs = [images[source]],
            disallow_nopic_outputs = True,
        )
        objects.extend(compiled.pic_objects)
    return [DefaultInfo(files = depset(objects))]

_cuda_payload = rule(
    implementation = _cuda_payload_impl,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
    attrs = {
        "host": attr.label(mandatory = True, providers = [_CudaHostObjectsInfo]),
        "images": attr.label(mandatory = True, providers = [_CudaImagesInfo]),
    },
)

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

def _run_fatbinary(ctx, fatbin, cubins_by_arch):
    args = ctx.actions.args()
    args.add("--64")
    args.add(fatbin, format = "--create=%s")
    args.add("--compress-mode=size")
    inputs = []
    for arch in sorted(cubins_by_arch):
        cubins = cubins_by_arch[arch]
        inputs.extend(cubins)
        args.add_all(cubins, format_each = "--image3=kind=elf,sm=%s,file=%%s" % arch.removeprefix("sm_"))
    if not inputs:
        fail("cuda_fatbinary requires deps that produce at least one cubin file")
    ctx.actions.run(
        mnemonic = "CudaFatbin",
        progress_message = "Creating fatbin %s" % fatbin.short_path,
        executable = ctx.executable._fatbinary,
        inputs = inputs,
        outputs = [fatbin],
        arguments = [args],
    )

def _cuda_fatbinary_impl(ctx):
    fatbin = ctx.actions.declare_file(ctx.label.name + ".fatbin")
    cubins_by_arch = {}
    for arch, deps in ctx.split_attr.deps.items():
        cubins_by_arch[arch] = []
        for dep in deps:
            # Exclude transitive host libraries from the device image.
            cubins = []
            for linker_input in dep[CcInfo].linking_context.linker_inputs.to_list():
                if linker_input.owner == dep.label:
                    for library in linker_input.libraries:
                        cubins.extend(library.pic_objects or [])
            if not cubins:
                fail("cuda_fatbinary requires direct PIC device objects from %s for %s" % (dep.label, arch))
            cubins_by_arch[arch].extend(cubins)
    _run_fatbinary(ctx, fatbin, cubins_by_arch)
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

def _cuda_images_impl(ctx):
    by_arch = {arch: dep[_CudaCompilationInfo].units for arch, dep in ctx.split_attr.dep.items()}
    archs = sorted(by_arch)
    sources = sorted(by_arch[archs[0]])
    for arch in archs:
        if sorted(by_arch[arch]) != sources:
            fail("CUDA sources differ between GPU architectures")
    images = {}
    for source in sources:
        fatbin = ctx.actions.declare_file("%s/%d.fatbin" % (ctx.label.name, len(images)))
        cubins_by_arch = {}
        for arch in archs:
            cubins = by_arch[arch][source].pic_objects
            if len(cubins) != 1:
                fail("Expected one PIC cubin for %s on %s" % (source, arch))
            cubins_by_arch[arch] = cubins
        _run_fatbinary(ctx, fatbin, cubins_by_arch)
        images[source] = fatbin
    return [DefaultInfo(files = depset(images.values())), _CudaImagesInfo(images = images)]

_cuda_images = rule(
    implementation = _cuda_images_impl,
    attrs = {
        "dep": attr.label(mandatory = True, cfg = _cuda_arch_transition, providers = [CcInfo], aspects = [_cuda_compilation]),
        "archs": attr.string_list(),
        "_fatbinary": attr.label(
            default = Label("//toolchain/cuda:current_fatbinary"),
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
)

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
    """Compiles host and device code independently, joining them at CPU link.

    `deps` supplies headers to device compilation and libraries to host linking.
    `host_deps` is only available to host compilation/linking. Device code must
    be self-contained in each translation unit (no relocatable device code).
    Each source must emit CUDA device registration; use cc_library for CPU-only
    sources. Native cc_library attributes below retain their compilation/link
    semantics.
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
    compiler_inputs = kwargs.get("additional_compiler_inputs", [])

    host_objects = []
    host_context = []
    if srcs:
        dev_src_target = name + "__cuda_dev"
        fatbin_src_target = name + "__fatbins"
        raw_host_target = name + "__cuda_host_raw"
        host_objects_target = name + "__cuda_host_objects"
        payload_target = name + "__cuda_host_payload"

        cc_library(
            name = dev_src_target,
            srcs = srcs,
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
        _cuda_images(
            name = fatbin_src_target,
            dep = dev_src_target,
            archs = archs,
            visibility = ["//visibility:private"],
            **common_kwargs
        )

        cc_library(
            name = raw_host_target,
            srcs = srcs,
            hdrs = hdrs,
            defines = defines,
            deps = deps + host_deps,
            # Native ELF is required by the relocation tool. Other CPU targets
            # can still use ThinLTO when linking these ordinary native objects.
            features = features + ["-thin_lto"],
            copts = copts + [
                "--cuda-path=$(location {})".format(Label("//toolchain/cuda:current_cuda_path")),
                "--offload-host-only",
                "-Xclang",
                "-fcuda-include-gpubinary",
                "-Xclang",
                "$(execpath {})".format(Label("//toolchain/cuda:empty.fatbin")),
            ] + [
                "-Wno-error=invalid-specialization",
            ],
            additional_compiler_inputs = compiler_inputs + [
                Label("//toolchain/cuda:current_cuda_path"),
                Label("//toolchain/cuda:empty.fatbin"),
            ],
            visibility = ["//visibility:private"],
            **compile_kwargs
        )

        _cuda_host_objects(
            name = host_objects_target,
            raw = raw_host_target,
            visibility = ["//visibility:private"],
            **common_kwargs
        )
        _cuda_payload(
            name = payload_target,
            host = host_objects_target,
            images = fatbin_src_target,
            features = features,
            visibility = ["//visibility:private"],
            **common_kwargs
        )
        host_objects = [host_objects_target, payload_target]
        host_context = [host_objects_target]

    cc_library(
        name = name,
        srcs = host_objects,
        hdrs = hdrs,
        defines = defines,
        features = features,
        deps = host_context + deps + host_deps,
        **kwargs
    )
