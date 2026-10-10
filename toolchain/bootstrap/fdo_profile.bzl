"""Rules for generating an LLVM bootstrap FDO profile."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc:action_names.bzl", "ACTION_NAMES")
load("@rules_cc//cc:find_cc_toolchain.bzl", "CC_TOOLCHAIN_TYPE", "find_cc_toolchain", "use_cc_toolchain")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_cc//cc/common:cc_info.bzl", "CcInfo")
load("@rules_cc//cc/private/rules_impl/fdo:fdo_profile.bzl", "FdoProfileInfo")  # buildifier: disable=bzl-visibility
load(":transition_settings.bzl", "LLVM_TOOLS", "SANITIZER_FLAGS", "disable_sanitizers")

LLVMFDOProfilePassesInfo = provider(
    doc = "LLVM profiles of the training units for one target platform.",
    fields = {
        "units": "List of struct(name, profile): the sparse indexed .profdata of each " +
                 "training unit, a pass or a chunk of one.",
    },
)

_TrainingSourcesInfo = provider(
    doc = "Sources of a cc_library, collected to compile them as C++ training input.",
    fields = {
        "srcs": "List of the library's source files, including textual .inc and .h files.",
    },
)

# Workload flags, by compiler driver. MSVC-ABI targets use clang-cl, so the
# same workloads can later train an instrumented MSVC-ABI LLVM running on
# Windows. Link flags for clang-cl are lld-link flags: the toolchain forwards
# each user link flag to the linker.
_ZSTD_DEFINES = [
    "-DZSTD_DISABLE_ASM",
    "-DZSTD_MULTITHREAD",
    "-DZSTD_NOBENCH",
    "-DZSTD_NODICT",
    "-DZSTD_NODECOMPRESS",
    "-DZSTD_NOTRACE",
    "-UZSTD_LEGACY_SUPPORT",
    "-DZSTD_LEGACY_SUPPORT=0",
]

_GNU_FLAGS = struct(
    c = ["-x", "c"],
    hosted_c = ["-pthread"] + _ZSTD_DEFINES,
    freestanding_c = [
        "-ffreestanding",
        "-fno-builtin",
        "-nostdinc",
    ],
    # Freestanding passes: an optimized build, and the optimized build with
    # debug info that BPF programs use for BTF.
    freestanding_passes = {
        "freestanding": [
            "-O3",
            "-fomit-frame-pointer",
            "-ffunction-sections",
            "-fdata-sections",
        ],
        "freestanding_O2_g": [
            "-O2",
            "-g",
        ],
    },
    # Optimized ThinLTO build: trains the frontend and IR optimizer when
    # compiling, and the ThinLTO backend, codegen and linker when linking.
    lto_compile = [
        "-O3",
        "-fomit-frame-pointer",
        "-ffunction-sections",
        "-fdata-sections",
        "-flto=thin",
    ],
    lto_link = [
        "-O3",
        "-flto=thin",
        "-pthread",
    ],
    # Unoptimized build with debug info: trains -O0 codegen, debug info
    # emission, and the linker's handling of debug info. Windows targets emit
    # CodeView and link a PDB; macOS targets create a dSYM with dsymutil.
    debug_compile = [
        "-O0",
        "-g",
    ],
    windows_debug_compile = ["-gcodeview"],
    debug_link = [
        "-g",
        "-pthread",
    ],
    pdb_link = lambda path: ["-Wl,--pdb=" + path],
    # C++ passes over cxx_library: a typical optimized build, and a debug build.
    cxx_passes = {
        "cxx_O0_g": [
            "-O0",
            "-g",
        ],
        "cxx_O2": [
            "-O2",
            "-ffunction-sections",
            "-fdata-sections",
        ],
    },
)

_CLANG_CL_FLAGS = struct(
    c = ["/TC"],
    hosted_c = _ZSTD_DEFINES,
    freestanding_c = None,
    freestanding_passes = None,
    lto_compile = [
        "/O2",
        "/Gy",
        "/Gw",
        "/clang:-flto=thin",
    ],
    # lld-link runs ThinLTO for bitcode inputs without extra flags.
    lto_link = [],
    debug_compile = [
        "/Od",
        "/Z7",
    ],
    windows_debug_compile = [],
    debug_link = ["/DEBUG"],
    pdb_link = lambda path: ["/PDB:" + path],
    cxx_passes = {
        "cxx_O0_g": [
            "/Od",
            "/Z7",
        ],
        "cxx_O2": [
            "/O2",
            "/Gy",
            "/Gw",
        ],
    },
)

# C++ passes compile their sources in chunks of about this many files, one
# action each, so remote executors and sharded training spread them out.
_CXX_CHUNK_SIZE = 24

# Features the release configuration enables for LLVM itself, which would leak
# into the workloads: each pass sets its own LTO mode, and C++ training input
# keeps exceptions and RTTI like typical user code.
_WORKLOAD_DISABLED_FEATURES = [
    "no_exceptions",
    "no_rtti",
    "thin_lto",
]

def _uses_prebuilt_training_compiler(settings):
    return settings["//toolchain/bootstrap:fdo_training_compiler"] == "prebuilt"

def _profile_generation_transition_impl(settings, attr):
    transition_settings = {
        "//command_line_option:fdo_profile": None,
        "//command_line_option:platforms": str(attr.target_platform),
        "//toolchain:runtime_stage": "complete",
        # The prebuilt compiler of a training host is its Stage 0, replaced by
        # an instrumented Stage 2 archive. The workloads' target runtimes still
        # build with the Stage 0 of other, remote executors.
        "//toolchain:bootstrap_stage": "stage0_prebuilt_seed" if _uses_prebuilt_training_compiler(settings) else "stage2_lto_and_fdo_instrumented",
        "@llvm-project//llvm:driver-tools": LLVM_TOOLS,
        # Only the profile merge selects a shard's units. Every shard builds
        # the same workloads, which share their runtimes in the remote cache.
        "//toolchain/bootstrap:fdo_training_shard": "",
    }

    disable_sanitizers(transition_settings)

    return transition_settings

_profile_generation_transition = transition(
    implementation = _profile_generation_transition_impl,
    inputs = ["//toolchain/bootstrap:fdo_training_compiler"],
    outputs = [
        "//command_line_option:fdo_profile",
        "//command_line_option:platforms",
        "//toolchain:runtime_stage",
        "//toolchain:bootstrap_stage",
        "//toolchain/bootstrap:fdo_training_shard",
        "@llvm-project//llvm:driver-tools",
    ] + SANITIZER_FLAGS,
)

def _profile_merge_transition_impl(settings, _attr):
    return {
        "//command_line_option:fdo_profile": None,
        # A prebuilt training run needs no source-built LLVM: the Stage 0
        # llvm-profdata reads the raw profiles of the same LLVM version.
        "//toolchain:bootstrap_stage": "stage0_prebuilt_seed" if _uses_prebuilt_training_compiler(settings) else "stage1_from_source",
    }

_profile_merge_transition = transition(
    implementation = _profile_merge_transition_impl,
    inputs = ["//toolchain/bootstrap:fdo_training_compiler"],
    outputs = [
        "//command_line_option:fdo_profile",
        "//toolchain:bootstrap_stage",
    ],
)

def _training_sources_aspect_impl(_target, ctx):
    return [_TrainingSourcesInfo(srcs = ctx.rule.files.srcs)]

_training_sources_aspect = aspect(
    implementation = _training_sources_aspect_impl,
    doc = "Collects the sources of a cc_library to compile them as training input.",
)

def _shell_quote(value):
    return "'" + value.replace("'", "'\\''") + "'"

def _shell_command(tool, args, env = {}):
    return " ".join(
        ["%s=%s" % (name, _shell_quote(value)) for name, value in sorted(env.items())] +
        [_shell_quote(tool)] +
        [_shell_quote(arg) for arg in args],
    )

# Runs one training pass: its compiles in parallel, then its link, then merges
# the pass's profile. Every instrumented process (driver, lld, dsymutil) merges
# its counters online into a small pool of raw profiles, since each raw profile
# holds counters for all of LLVM. Intermediate files are deleted, leaving the
# pass's sparse indexed profile as its only output.
_PASS_SCRIPT = """\
set -u
# Keep Git Bash on Windows from rewriting clang-cl /flags as paths.
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'
work={work}
rm -rf "$work"
mkdir -p "$work/objects" "$work/profiles"
export LLVM_PROFILE_FILE="$work/profiles/%8m.profraw"
jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
running=0
throttle() {{
  running=$((running + 1))
  if [ "$running" -ge "$jobs" ]; then
    wait
    running=0
  fi
}}
{compiles}
wait
if [ -e "$work/failed" ]; then
  echo "LLVM FDO training: a compile failed" >&2
  exit 1
fi
{link}
LLVM_PROFILE_FILE="$work/llvm-profdata-%p.profraw" {merge} || exit 1
rm -rf "$work"
mkdir -p "$work"
"""

def _training_pass_resources(_os, _inputs_size):
    # The pass runs as many processes as the machine has cores.
    return {"cpu": 64}

def _compile_command(toolchain, work, index, source, flags, compilation_context):
    cc = compilation_context
    variables = {
        "cc_toolchain": toolchain.cc_toolchain,
        "feature_configuration": toolchain.feature_configuration,
        "output_file": "%s/objects/%s.o" % (work, index),
        "source_file": source.path,
        "user_compile_flags": flags,
    }
    if cc:
        action_name = ACTION_NAMES.cpp_compile
        variables.update(
            include_directories = cc.includes,
            quote_include_directories = cc.quote_includes,
            system_include_directories = cc.system_includes,
            framework_include_directories = cc.framework_includes,
            preprocessor_defines = depset(transitive = [cc.defines, cc.local_defines]),
        )
    else:
        action_name = ACTION_NAMES.c_compile
        variables["include_directories"] = toolchain.c_include_directories
    compile_variables = cc_common.create_compile_variables(**variables)
    return struct(
        command = _shell_command(
            cc_common.get_tool_for_action(
                feature_configuration = toolchain.feature_configuration,
                action_name = action_name,
            ),
            cc_common.get_memory_inefficient_command_line(
                feature_configuration = toolchain.feature_configuration,
                action_name = action_name,
                variables = compile_variables,
            ),
        ),
        env = cc_common.get_environment_variables(
            feature_configuration = toolchain.feature_configuration,
            action_name = action_name,
            variables = compile_variables,
        ),
        object = variables["output_file"],
    )

def _link_command(toolchain, work, objects, flags, pdb, dsym):
    binary = work + "/objects/training.bin"
    if pdb:
        flags = flags + toolchain.flags.pdb_link(binary + ".pdb")
    variables = cc_common.create_link_variables(
        cc_toolchain = toolchain.cc_toolchain,
        feature_configuration = toolchain.feature_configuration,
        output_file = binary,
        user_link_flags = flags,
    )
    env = dict(cc_common.get_environment_variables(
        feature_configuration = toolchain.feature_configuration,
        action_name = ACTION_NAMES.cpp_link_executable,
        variables = variables,
    ))
    if dsym:
        # Read by link_wrapper.c, like the generate_dsym_file feature sets them
        # from the dsym_path link variable, which create_link_variables lacks.
        env["LLVM_DSYM_PATH"] = binary + ".dSYM"
        env["LLVM_LINK_OUTPUT"] = binary
    return _shell_command(
        cc_common.get_tool_for_action(
            feature_configuration = toolchain.feature_configuration,
            action_name = ACTION_NAMES.cpp_link_executable,
        ),
        cc_common.get_memory_inefficient_command_line(
            feature_configuration = toolchain.feature_configuration,
            action_name = ACTION_NAMES.cpp_link_executable,
            variables = variables,
        ) + objects,
        env = env,
    )

def _training_pass(ctx, toolchain, pass_name, sources, flags, inputs, compilation_context = None, link_flags = None, pdb = False, dsym = False):
    """Declares the action of one training pass, returning its .profdata.

    Compiles sources with flags, then links them unless link_flags is None. With
    pdb, the link also writes a PDB; with dsym, the macOS link wrapper also runs
    dsymutil.
    """
    name = "%s.%s" % (ctx.label.name, pass_name)
    work_dir = ctx.actions.declare_directory(name + ".work")
    profdata = ctx.actions.declare_file(name + ".profdata")
    script = ctx.actions.declare_file(name + ".sh")

    compiles = [
        _compile_command(toolchain, work_dir.path, index, source, flags, compilation_context)
        for index, source in enumerate(sources)
    ]
    link = ""
    if link_flags != None:
        link = _link_command(toolchain, work_dir.path, [compile.object for compile in compiles], link_flags, pdb, dsym) + " || exit 1"

    ctx.actions.write(
        output = script,
        content = _PASS_SCRIPT.format(
            work = _shell_quote(work_dir.path),
            compiles = "\n".join([
                '{ %s; } || : > "$work/failed" &\nthrottle' % compile.command
                for compile in compiles
            ]),
            link = link,
            merge = _shell_command(
                cc_common.get_tool_for_action(
                    feature_configuration = toolchain.feature_configuration,
                    action_name = ACTION_NAMES.llvm_profdata,
                ),
                ["merge", "--sparse", "--output", profdata.path],
            ) + ' "$work"/profiles/*.profraw',
        ),
    )

    ctx.actions.run_shell(
        command = "bash " + script.path,
        env = compiles[0].env if compiles else {},
        inputs = depset([script] + sources, transitive = [inputs] + ([compilation_context.headers] if compilation_context else [])),
        tools = toolchain.cc_toolchain.all_files,
        outputs = [
            profdata,
            work_dir,
        ],
        mnemonic = "LLVMFDOProfileTrain",
        progress_message = "Training LLVM FDO profile with %{label} (" + pass_name + ")",
        resource_set = _training_pass_resources,
        toolchain = CC_TOOLCHAIN_TYPE,
    )
    return profdata

def _llvm_fdo_profile_workload_impl(ctx):
    def has_constraint(attr):
        return ctx.target_platform_has_constraint(attr[platform_common.ConstraintValueInfo])

    is_windows = has_constraint(ctx.attr._windows_constraint)
    flags = _CLANG_CL_FLAGS if has_constraint(ctx.attr._msvc_constraint) else _GNU_FLAGS

    cc_toolchain = find_cc_toolchain(ctx)
    toolchain = struct(
        cc_toolchain = cc_toolchain,
        feature_configuration = cc_common.configure_features(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            requested_features = [feature for feature in ctx.features if feature not in _WORKLOAD_DISABLED_FEATURES],
            unsupported_features = ctx.disabled_features + _WORKLOAD_DISABLED_FEATURES,
        ),
        c_include_directories = depset(sorted({file.dirname: None for file in ctx.files.srcs}.keys())),
        flags = flags,
    )
    c_sources = [file for file in ctx.files.srcs if file.extension == "c"]
    c_inputs = ctx.attr.srcs[DefaultInfo].files

    units = []

    def add_unit(unit_name, profile):
        units.append(struct(name = "%s:%s" % (ctx.label.name, unit_name), profile = profile))

    if ctx.attr.workload_kind == "freestanding":
        if ctx.attr.cxx_library or flags.freestanding_c == None:
            fail("freestanding workloads only compile C with the clang driver")
        for pass_name, pass_flags in flags.freestanding_passes.items():
            add_unit(pass_name, _training_pass(ctx, toolchain, pass_name, c_sources, flags.c + flags.freestanding_c + pass_flags, c_inputs))
    else:
        add_unit("lto", _training_pass(
            ctx,
            toolchain,
            "lto",
            c_sources,
            flags.c + flags.hosted_c + flags.lto_compile,
            c_inputs,
            link_flags = flags.lto_link,
        ))
        add_unit("debug", _training_pass(
            ctx,
            toolchain,
            "debug",
            c_sources,
            flags.c + flags.hosted_c + flags.debug_compile + (flags.windows_debug_compile if is_windows else []),
            c_inputs,
            link_flags = flags.debug_link,
            pdb = is_windows,
            dsym = has_constraint(ctx.attr._macos_constraint),
        ))
        if ctx.attr.cxx_library:
            library = ctx.attr.cxx_library
            srcs = library[_TrainingSourcesInfo].srcs
            cxx_sources = [file for file in srcs if file.extension == "cpp"]
            chunk_count = (len(cxx_sources) + _CXX_CHUNK_SIZE - 1) // _CXX_CHUNK_SIZE
            for pass_name, pass_flags in flags.cxx_passes.items():
                for chunk in range(chunk_count):
                    unit_name = "%s.%s" % (pass_name, chunk)
                    add_unit(unit_name, _training_pass(
                        ctx,
                        toolchain,
                        unit_name,
                        # Interleaved, so chunks get similar sources.
                        cxx_sources[chunk::chunk_count],
                        pass_flags,
                        depset(srcs),
                        compilation_context = library[CcInfo].compilation_context,
                    ))

    return [
        DefaultInfo(files = depset([unit.profile for unit in units])),
        LLVMFDOProfilePassesInfo(units = units),
    ]

llvm_fdo_profile_workload = rule(
    implementation = _llvm_fdo_profile_workload_impl,
    attrs = {
        "cxx_library": attr.label(
            aspects = [_training_sources_aspect],
            providers = [CcInfo],
            doc = "Optional cc_library whose C++ sources are also compiled for target_platform, " +
                  "at -O2 and at -O0 -g. Hosted workloads only.",
        ),
        "srcs": attr.label(
            allow_files = [".c", ".h"],
            mandatory = True,
            doc = "C training sources compiled for target_platform.",
        ),
        "target_platform": attr.label(
            mandatory = True,
            doc = "Target platform compiled by this training workload.",
        ),
        "workload_kind": attr.string(
            mandatory = True,
            values = [
                "freestanding",
                "hosted",
            ],
            doc = "Whether this workload compiles only, or also links optimized and debug builds.",
        ),
        "_macos_constraint": attr.label(
            default = Label("@platforms//os:macos"),
            providers = [platform_common.ConstraintValueInfo],
        ),
        "_msvc_constraint": attr.label(
            default = Label("//constraints/windows/abi:msvc"),
            providers = [platform_common.ConstraintValueInfo],
        ),
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
            providers = [platform_common.ConstraintValueInfo],
        ),
    },
    cfg = _profile_generation_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _llvm_fdo_profile_data_impl(ctx):
    cc_toolchain = find_cc_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )
    llvm_profdata = cc_common.get_tool_for_action(
        feature_configuration = feature_configuration,
        action_name = ACTION_NAMES.llvm_profdata,
    )
    profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")
    units = [
        unit
        for profile in ctx.attr.profiles
        for unit in profile[LLVMFDOProfilePassesInfo].units
    ]

    # A sharded training run builds only the units of its shard.
    shard = ctx.attr._training_shard[BuildSettingInfo].value
    if shard:
        index, count = [int(part) for part in shard.split("/")]
        if count < 1 or index < 0 or index >= count:
            fail("invalid --//toolchain/bootstrap:fdo_training_shard=%s, expected <index>/<count>" % shard)
        units = [unit for unit in units if hash(unit.name) % count == index]
    if not units:
        fail("%s has no training units to merge" % ctx.label)
    pass_profiles = depset([unit.profile for unit in units])

    merge_args = ctx.actions.args()
    merge_args.add("merge")
    merge_args.add("--output")
    merge_args.add(profdata)
    merge_args.add_all(pass_profiles)

    ctx.actions.run(
        executable = llvm_profdata,
        arguments = [merge_args],
        inputs = pass_profiles,
        tools = cc_toolchain.all_files,
        outputs = [profdata],
        mnemonic = "LLVMFDOProfileMerge",
        progress_message = "Merging LLVM FDO profiles for %{label}",
        execution_requirements = {"supports-path-mapping": "1"},
        toolchain = CC_TOOLCHAIN_TYPE,
    )

    return [
        DefaultInfo(files = depset([profdata])),
        FdoProfileInfo(
            artifact = profdata,
            proto_profile_artifact = None,
            memprof_artifact = None,
        ),
    ]

llvm_fdo_profile_data = rule(
    implementation = _llvm_fdo_profile_data_impl,
    attrs = {
        "profiles": attr.label_list(
            mandatory = True,
            providers = [LLVMFDOProfilePassesInfo],
            doc = "Target-platform training workloads merged into this profile.",
        ),
        "_training_shard": attr.label(
            default = "//toolchain/bootstrap:fdo_training_shard",
            providers = [BuildSettingInfo],
        ),
    },
    cfg = _profile_merge_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)

def _llvm_fdo_profile_import_impl(ctx):
    if not ctx.files.srcs:
        fail("%s has no .profdata file" % ctx.label)
    if len(ctx.files.srcs) == 1:
        profdata = ctx.files.srcs[0]
    else:
        # Profiles of a sharded training run.
        cc_toolchain = find_cc_toolchain(ctx)
        feature_configuration = cc_common.configure_features(
            ctx = ctx,
            cc_toolchain = cc_toolchain,
            requested_features = ctx.features,
            unsupported_features = ctx.disabled_features,
        )
        profdata = ctx.actions.declare_file(ctx.label.name + ".profdata")
        merge_args = ctx.actions.args()
        merge_args.add("merge")
        merge_args.add("--output")
        merge_args.add(profdata)
        merge_args.add_all(ctx.files.srcs)
        ctx.actions.run(
            executable = cc_common.get_tool_for_action(
                feature_configuration = feature_configuration,
                action_name = ACTION_NAMES.llvm_profdata,
            ),
            arguments = [merge_args],
            inputs = ctx.files.srcs,
            tools = cc_toolchain.all_files,
            outputs = [profdata],
            mnemonic = "LLVMFDOProfileMerge",
            progress_message = "Merging LLVM FDO profile shards for %{label}",
            toolchain = CC_TOOLCHAIN_TYPE,
        )
    return [
        DefaultInfo(files = depset([profdata])),
        FdoProfileInfo(
            artifact = profdata,
            proto_profile_artifact = None,
            memprof_artifact = None,
        ),
    ]

llvm_fdo_profile_import = rule(
    implementation = _llvm_fdo_profile_import_impl,
    doc = "An LLVM FDO profile produced outside this build, such as by training on another host.",
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".profdata"],
            doc = "The .profdata files, merged if there are several, like the shards of a " +
                  "training run. A list, so a glob can be empty until the profile is placed.",
        ),
    },
    # Merges outside the configuration that applies the profile, whose
    # toolchain depends on this profile.
    cfg = _profile_merge_transition,
    fragments = ["cpp"],
    toolchains = use_cc_toolchain(),
)
