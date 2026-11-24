# Ports the object lists of libgcc/Makefile.in and of the tmake fragments that
# libgcc/config.host selects for each ported target. _TMAKE_FILES lists them.
# Each fragment's contribution is marked with its file name. Only the startfile
# fragments (crtstuff, crtprec, crtfastmath) and the decimal floating-point
# objects are left out: the toolchain keeps compiler-rt's crtbegin/crtend, and
# Clang has no decimal floating-point types, so libgcc's configure would set
# decimal_float=no.
#
# The result splits objects the way libgcc/Makefile.in does:
#   common: libgcc-objects that also have an _s variant in libgcc-s-objects
#   static_only: libgcc-objects without an _s variant (LIB2ADD_ST, LIB2FUNCS_ST,
#     and objects that tmake fragments build with their own rules)
#   eh: LIB2ADDEH, archived into libgcc_eh.a and linked into libgcc_s.so.1
# Every entry is struct(name, src, copts, defines, vis_hide). libgcc2.c entries
# have src = None: they are compiled from a generated wrapper that defines
# L<name>. Entries with defines are compiled from a wrapper that defines them,
# in place of the -D flags their rule passes. vis_hide is False for objects
# whose rule compiles them without libgcc's vis_hide flags or hide list.

load("//3rd_party/gcc:version.bzl", "gcc_version_at_least_for")

# The tmake_file list that libgcc/config.host and libgcc/configure.ac select,
# in their order, for GCC 17. libgcc_tmake_files adjusts it for older versions.
# //runtimes/libgcc/tests:configure_* runs config.host and checks its result
# against the list.
_TMAKE_FILES = {
    "aarch64": [
        "t-crtstuff-pic",
        "t-libgcc-pic",
        "t-eh-dw2-dip",
        "t-slibgcc",
        "t-slibgcc-gld",
        "t-slibgcc-elf-ver",
        "t-linux",
        "aarch64/t-aarch64",
        "aarch64/t-lse",
        "t-slibgcc-libgcc",
        "aarch64/t-softfp",
        "t-softfp",
        "t-crtfm",
        "t-dfprules",
        "aarch64/t-heap-trampoline",
    ],
    "x86_64": [
        "t-crtstuff-pic",
        "t-libgcc-pic",
        "t-eh-dw2-dip",
        "t-slibgcc",
        "t-slibgcc-gld",
        "t-slibgcc-elf-ver",
        "t-linux",
        "i386/t-crtpc",
        "t-crtfm",
        "i386/t-crtstuff",
        "t-dfprules",
        "i386/t-heap-trampoline",
        "i386/t-cpuinfo",
        "t-tls",
        "i386/t-linux",
        "i386/t-msabi",
        "t-slibgcc-libgcc",
        "t-stack",
        "i386/t-stack-i386",
        "t-softfp-tf",
        "i386/64/t-softfp",
        "i386/t-softfp",
        "t-softfp",
        "i386/64/t-softfp-compat",
    ],
}

_LIB2FUNCS = [
    "_muldi3",
    "_negdi2",
    "_lshrdi3",
    "_ashldi3",
    "_ashrdi3",
    "_cmpdi2",
    "_ucmpdi2",
    "_clear_cache",
    "_trampoline",
    "__main",
    "_absvsi2",
    "_absvdi2",
    "_addvsi3",
    "_addvdi3",
    "_subvsi3",
    "_subvdi3",
    "_mulvsi3",
    "_mulvdi3",
    "_negvsi2",
    "_negvdi2",
    "_ctors",
    "_ffssi2",
    "_ffsdi2",
    "_clz",
    "_clzsi2",
    "_clzdi2",
    "_ctzsi2",
    "_ctzdi2",
    "_popcount_tab",
    "_popcountsi2",
    "_popcountdi2",
    "_paritysi2",
    "_paritydi2",
    "_powisf2",
    "_powidf2",
    "_powixf2",
    "_powitf2",
    "_mulhc3",
    "_mulsc3",
    "_muldc3",
    "_mulxc3",
    "_multc3",
    "_divhc3",
    "_divsc3",
    "_divdc3",
    "_divxc3",
    "_divtc3",
    "_bswapsi2",
    "_bswapdi2",
    "_clrsbsi2",
    "_clrsbdi2",
]

_LIB2_DIVMOD_FUNCS = [
    "_divdi3",
    "_moddi3",
    "_divmoddi4",
    "_udivdi3",
    "_umoddi3",
    "_udivmoddi4",
    "_udiv_w_sdiv",
]

_LIB2FUNCS_ST = [
    "_eprintf",
    "__gcc_bcmp",
]

# Makefile.in: LIB2_DIVMOD_EXCEPTION_FLAGS default.
_LIB2_DIVMOD_EXCEPTION_FLAGS = [
    "-fexceptions",
    "-fnon-call-exceptions",
]

def _swfloatfuncs(xx):
    return ["_fixuns{}{}".format(m, xx) for m in ["sf", "df", "xf"]]

def _dwfloatfuncs(xx):
    modes = ["sf", "df", "xf", "tf"]
    return (["_fix{}{}".format(m, xx) for m in modes] +
            ["_fixuns{}{}".format(m, xx) for m in modes] +
            ["_float{}{}".format(xx, m) for m in modes] +
            ["_floatun{}{}".format(xx, m) for m in modes])

def _softfp(state):
    """t-softfp: composes softfp_func_list from the variables set before it."""
    funcs = []
    for m in state.float_modes:
        funcs += [f.format(m = m) for f in [
            "add{m}3",
            "div{m}3",
            "eq{m}2",
            "ge{m}2",
            "le{m}2",
            "mul{m}3",
            "neg{m}2",
            "sub{m}3",
            "unord{m}2",
        ]]
        for i in state.int_modes:
            funcs += [f.format(m = m, i = i) for f in [
                "fix{m}{i}",
                "fixuns{m}{i}",
                "float{i}{m}",
                "floatun{i}{m}",
            ]]
    funcs += ["extend{}2".format(e) for e in state.extensions]
    funcs += ["trunc{}2".format(t) for t in state.truncations]
    funcs += state.extras
    bitint_funcs = []
    if state.bitint:
        for m in ["sf", "df"]:
            bitint_funcs += ["fix{}bitint".format(m), "floatbitint{}".format(m)]
    exclude = []
    if not state.exclude_libgcc2:
        for m in state.float_modes:
            for i in ["si", "di"]:
                exclude += [f.format(m = m, i = i) for f in [
                    "_fix{m}{i}",
                    "_fixuns{m}{i}",
                    "_float{i}{m}",
                    "_floatun{i}{m}",
                ]]
    return funcs + bitint_funcs, exclude

def _features(version):
    """The libgcc features of a GCC version that change its object lists.

    Each threshold is a major version whose earliest release in GCC_VERSIONS
    has the feature.
    """
    return struct(
        # _BitInt (libgcc2.c, soft-fp), the heap trampolines, hardcfr.c and
        # strub.c.
        gcc14 = gcc_version_at_least_for(version, "14.0.0"),
        # The __bf16 conversions in i386/t-softfp and i386/64/t-softfp.
        bf16 = gcc_version_at_least_for(version, "13.0.0"),
        # The _Float16 functions in i386/t-softfp and i386/64/t-softfp.
        float16 = gcc_version_at_least_for(version, "12.0.0"),
    )

def _x86_64_linux_gnu(version):
    features = _features(version)
    lib2add = []
    lib2add_st = []
    lib2addeh = [
        # t-eh-dw2-dip
        "libgcc/unwind-dw2.c",
        "libgcc/unwind-dw2-fde-dip.c",
        "libgcc/unwind-sjlj.c",
        "libgcc/unwind-c.c",
    ]
    if features.gcc14:
        # i386/t-heap-trampoline
        lib2addeh.append("libgcc/config/i386/heap-trampoline.c")
    lib2funcs_exclude = []

    # Per-file CFLAGS-<file> from i386/64/t-softfp and i386/t-softfp. The
    # misspelled floatunstihf and floatunstibf entries are kept as GCC has
    # them, so floatuntihf and floatuntibf get no -msse2 there either.
    sse2_files = []
    if features.float16:
        sse2_files += [
            "fixhfti",
            "fixunshfti",
            "floattihf",
            "floatunstihf",
        ]
    if features.bf16:
        sse2_files += [
            "floattibf",
            "floatunstibf",
        ]
    if features.float16:
        sse2_files += [
            "extendhfsf2",
            "extendhfdf2",
            "extendhftf2",
            "extendhfxf2",
        ]
    if features.bf16:
        sse2_files.append("extendbfsf2")
    if features.float16:
        sse2_files += [
            "truncsfhf2",
            "truncdfhf2",
            "truncxfhf2",
            "trunctfhf2",
        ]
    if features.bf16:
        sse2_files += [
            "truncsfbf2",
            "truncdfbf2",
            "truncxfbf2",
            "trunctfbf2",
            "trunchfbf2",
        ]
    if features.gcc14:
        sse2_files += [
            "floatbitintbf",
            "floatbitinthf",
        ]
    if features.float16:
        sse2_files += [
            "eqhf2",
            "_divhc3",
            "_mulhc3",
        ]

    # i386/t-cpuinfo
    lib2add.append("libgcc/config/i386/cpuinfo.c")

    # i386/t-msabi
    lib2add_st += ["libgcc/config/i386/{}.S".format(f) for f in [
        "avx_savms64",
        "avx_resms64",
        "avx_resms64x",
        "avx_savms64f",
        "avx_resms64f",
        "avx_resms64fx",
        "sse_savms64",
        "sse_resms64",
        "sse_resms64x",
        "sse_savms64f",
        "sse_resms64f",
        "sse_resms64fx",
    ]]

    # t-stack and i386/t-stack-i386 (libgcc_cv_cfi=yes with Clang).
    lib2add_st += [
        "libgcc/generic-morestack.c",
        "libgcc/generic-morestack-thread.c",
        "libgcc/config/i386/morestack.S",
    ]

    # t-softfp-tf, then i386/64/t-softfp, then i386/t-softfp, in config.host
    # order. i386/t-softfp assigns softfp_extensions and softfp_truncations
    # with :=, replacing the t-softfp-tf values, from GCC 12.
    extensions = ["sftf", "dftf", "xftf"]
    truncations = ["tfsf", "tfdf", "tfxf"]
    extras = []
    if features.gcc14:
        # t-softfp-tf
        extras += [
            "fixtfbitint",
            "floatbitinttf",
        ]
    if features.float16:
        extensions = ["hfsf", "hfdf", "hftf", "hfxf", "sfdf", "sftf", "dftf", "xftf"]
        truncations = ["tfhf", "xfhf", "dfhf", "sfhf", "tfsf", "dfsf", "tfdf", "tfxf"]

        # i386/64/t-softfp
        extras += [
            "fixhfti",
            "fixunshfti",
            "floattihf",
            "floatuntihf",
        ]
    if features.bf16:
        extensions.append("bfsf")
        truncations += ["tfbf", "xfbf", "dfbf", "sfbf", "hfbf"]

        # i386/64/t-softfp
        extras += [
            "floattibf",
            "floatuntibf",
        ]
    if features.float16:
        # i386/t-softfp
        extras.append("eqhf2")
    if features.gcc14:
        # i386/t-softfp
        extras += [
            "fixxfbitint",
            "floatbitinthf",
            "floatbitintbf",
            "floatbitintxf",
        ]
    softfp = struct(
        float_modes = ["tf"],
        int_modes = ["si", "di", "ti"],
        extensions = extensions,
        truncations = truncations,
        extras = extras,
        exclude_libgcc2 = False,
        bitint = features.gcc14,
    )

    # i386/t-softfp: sfp-exceptions.c, and the HF complex functions from GCC 12.
    lib2add.append("libgcc/config/i386/sfp-exceptions.c")
    if features.float16:
        lib2funcs_exclude += ["_divhc3", "_mulhc3"]
        lib2add += ["libgcc/config/i386/_divhc3.c", "libgcc/config/i386/_mulhc3.c"]

    # t-softfp
    softfp_funcs, softfp_exclude = _softfp(softfp)
    lib2add += ["libgcc/soft-fp/{}.c".format(f) for f in softfp_funcs]
    lib2funcs_exclude += softfp_exclude

    # i386/64/t-softfp-compat
    tf_compats = ["getf2", "letf2", "eqtf2"]
    lib2add = [f for f in lib2add if f not in ["libgcc/soft-fp/{}.c".format(c) for c in tf_compats]]
    lib2add += ["libgcc/config/i386/64/{}.c".format(c) for c in tf_compats]
    libgcc2_tf_functions = ["_divtc3", "_multc3", "_powitf2"]
    lib2funcs_exclude += libgcc2_tf_functions
    lib2add += ["libgcc/config/i386/64/{}.c".format(f) for f in libgcc2_tf_functions]

    return _makefile_in(
        version = version,
        lib2add = lib2add,
        lib2add_st = lib2add_st,
        lib2addeh = lib2addeh,
        lib2funcs_exclude = lib2funcs_exclude,
        file_copts = {f: ["-msse2"] for f in sse2_files},
    )

def _aarch64_linux_gnu(version):
    lib2add = []
    lib2addeh = [
        # t-eh-dw2-dip
        "libgcc/unwind-dw2.c",
        "libgcc/unwind-dw2-fde-dip.c",
        "libgcc/unwind-sjlj.c",
        "libgcc/unwind-c.c",
    ]
    lib2funcs_exclude = []

    # aarch64/t-aarch64
    lib2add += [
        "libgcc/config/aarch64/sync-cache.c",
        "libgcc/config/aarch64/cpuinfo.c",
    ]
    lib2addeh += [
        "libgcc/config/aarch64/__aarch64_have_sme.c",
        "libgcc/config/aarch64/__arm_get_current_vg.S",
        "libgcc/config/aarch64/__arm_sme_state.S",
        "libgcc/config/aarch64/__arm_tpidr2_restore.S",
        "libgcc/config/aarch64/__arm_tpidr2_save.S",
        "libgcc/config/aarch64/__arm_za_disable.S",
    ]

    # aarch64/t-lse: the out-of-line atomics (one object per operation, size and
    # memory model, compiled from lse.S by their own rule) and lse-init.
    lse = []
    for op, sizes in [
        ("cas", [1, 2, 4, 8, 16]),
        ("swp", [1, 2, 4, 8]),
        ("ldadd", [1, 2, 4, 8]),
        ("ldclr", [1, 2, 4, 8]),
        ("ldeor", [1, 2, 4, 8]),
        ("ldset", [1, 2, 4, 8]),
    ]:
        for model in [1, 2, 3, 4, 5]:
            for size in sizes:
                lse.append(struct(
                    name = "{}_{}_{}".format(op, size, model),
                    src = "libgcc/config/aarch64/lse.S",
                    defines = ["L_" + op, "SIZE={}".format(size), "MODEL={}".format(model)],
                ))
    lse.append(struct(name = "lse-init", src = "libgcc/config/aarch64/lse-init.c", defines = []))

    # aarch64/t-softfp
    softfp = struct(
        float_modes = ["tf"],
        int_modes = ["si", "di", "ti"],
        extensions = ["sftf", "dftf", "hftf", "bfsf"],
        truncations = ["tfsf", "tfdf", "tfhf", "tfbf", "dfbf", "sfbf", "hfbf"],
        extras = [
            "fixhfti",
            "fixunshfti",
            "floattihf",
            "floatuntihf",
            "floatdibf",
            "floatundibf",
            "floattibf",
            "floatuntibf",
            "floatbitinthf",
            "floatbitintbf",
            "floatbitinttf",
            "fixtfbitint",
        ],
        exclude_libgcc2 = False,
        bitint = True,
    )
    lib2add.append("libgcc/config/aarch64/sfp-exceptions.c")

    # t-softfp
    softfp_funcs, softfp_exclude = _softfp(softfp)
    lib2add += ["libgcc/soft-fp/{}.c".format(f) for f in softfp_funcs]
    lib2funcs_exclude += softfp_exclude

    # aarch64/t-heap-trampoline
    lib2addeh.append("libgcc/config/aarch64/heap-trampoline.c")

    return _makefile_in(
        version = version,
        lib2add = lib2add,
        lib2add_st = [],
        lib2addeh = lib2addeh,
        lib2funcs_exclude = lib2funcs_exclude,
        own_rule_objects = lse,
    )

def _makefile_in(version, lib2add, lib2add_st, lib2addeh, lib2funcs_exclude, file_copts = {}, own_rule_objects = []):
    """Adds Makefile.in's defaults to the fragments' variables and partitions the objects.

    Args:
      version: The GCC version.
      lib2add: LIB2ADD from the fragments.
      lib2add_st: LIB2ADD_ST from the fragments.
      lib2addeh: LIB2ADDEH from the fragments.
      lib2funcs_exclude: LIB2FUNCS_EXCLUDE from the fragments.
      file_copts: CFLAGS-<file> from the fragments, by object name.
      own_rule_objects: struct(name, src, defines) for the libgcc-objects that
        fragments compile with their own rules, which add the defines as -D
        flags and neither vis_hide nor a hide list.

    Returns:
      The struct libgcc_objects returns.
    """

    gcc14 = _features(version).gcc14

    # Makefile.in: the LIB2ADD defaults, with hardcfr.c from GCC 14 and strub.c
    # from GCC 14 under HAVE_STRUB_SUPPORT, and the LIB2ADDEH emutls.c addition.
    lib2add = lib2add + ["enable-execute-stack.c"]
    if gcc14:
        lib2add += [
            "libgcc/hardcfr.c",
            "libgcc/strub.c",
        ]
    lib2addeh = lib2addeh + ["libgcc/emutls.c"]

    # Makefile.in: lib2funcs, including the conversion functions when
    # LIB2_SIDITI_CONV_FUNCS is unset, filtered by LIB2FUNCS_EXCLUDE. GCC 14
    # added the _BitInt functions.
    lib2funcs = _LIB2FUNCS + (["_mulbitint3"] if gcc14 else []) + _swfloatfuncs("si") + _dwfloatfuncs("di")
    lib2funcs = [f for f in lib2funcs if f not in lib2funcs_exclude]
    divmod = _LIB2_DIVMOD_FUNCS + (["_divmodbitint4"] if gcc14 else [])
    divmod = [f for f in divmod if f not in lib2funcs_exclude]
    lib2funcs_st = [f for f in _LIB2FUNCS_ST if f not in lib2funcs_exclude]

    def basename(path):
        return path.rsplit("/", 1)[-1].rsplit(".", 1)[0]

    def entry(name, src, copts = [], defines = [], vis_hide = True):
        return struct(name = name, src = src, copts = copts + file_copts.get(name, []), defines = defines, vis_hide = vis_hide)

    # static-object.mk and shared-object.mk compile assembly without c_flags.
    def lib2_entry(src, c_flags = []):
        return entry(basename(src), src, [] if src.endswith(".S") else c_flags)

    common = [entry(f, None) for f in lib2funcs]
    common += [entry(f, None, _LIB2_DIVMOD_EXCEPTION_FLAGS) for f in divmod]
    common += [lib2_entry(f) for f in lib2add]
    static_only = [entry(f, None) for f in lib2funcs_st]
    static_only += [lib2_entry(f) for f in lib2add_st]
    static_only += [entry(o.name, o.src, defines = o.defines, vis_hide = False) for o in own_rule_objects]

    # Makefile.in builds LIB2ADDEH with c_flags := -fexceptions.
    eh = [lib2_entry(f, ["-fexceptions"]) for f in lib2addeh]

    return struct(
        common = common,
        static_only = static_only,
        eh = eh,
    )

# The GCC versions whose Makefile.in and tmake fragments this file ports.
_PORTED_VERSIONS = [
    "10.5.0",
    "13.1.0",
    "13.2.0",
    "13.3.0",
    "13.4.0",
    "14.2.0",
    "14.3.0",
    "15.1.0",
    "15.2.0",
    "16.1.0",
    "17.0.0",
]

def libgcc_objects(cpu, version):
    """Partitions libgcc's objects for a Linux GNU target CPU.

    Fails for a version missing from _PORTED_VERSIONS and for a CPU whose
    objects are not ported.

    Args:
      cpu: The target CPU.
      version: The GCC version.

    Returns:
      A struct with common, static_only and eh lists of struct(name, src,
      copts, defines, vis_hide).
    """
    if version not in _PORTED_VERSIONS:
        fail("libgcc's object lists are ported for GCC {}, not {}".format(", ".join(_PORTED_VERSIONS), version))
    if cpu == "x86_64":
        return _x86_64_linux_gnu(version)
    if cpu == "aarch64" and version == "17.0.0":
        return _aarch64_linux_gnu(version)
    fail("libgcc's object lists are not ported for {} in GCC {}".format(cpu, version))

def libgcc_makefile_conditions(cpu, version):
    """The configure results that Makefile.in's conditionals read, as ported.

    //runtimes/libgcc/tests:configure_* checks them against configure's
    probes. Clang by default accepts neither decimal floating-point nor
    fixed-point types, so this file ports neither part: decimal_float and
    fixed_point are no.

    Returns:
      A dict from each Makefile.in variable to its value.
    """
    conditions = {
        "decimal_float": "no",
        "fixed_point": "no",
    }

    # GCC 14 added HAVE_STRUB_SUPPORT.
    if _features(version).gcc14:
        objects = libgcc_objects(cpu, version)
        conditions["have_strub_support"] = "yes" if "libgcc/strub.c" in [e.src for e in objects.common] else "no"
    return conditions

def libgcc_tmake_files(cpu, version):
    """Lists the tmake fragments config.host selects for cpu, which this file ports.

    Returns:
      The fragments in config.host order. Fails for a version or CPU whose
      objects are not ported.
    """
    libgcc_objects(cpu, version)
    features = _features(version)
    dropped = []
    if not features.gcc14:
        dropped.append("i386/t-heap-trampoline")
    if not features.float16:
        # config.host adds it from GCC 12. Older ones add i386/32/t-softfp for
        # 32-bit hosts only.
        dropped.append("i386/64/t-softfp")
    return [f for f in _TMAKE_FILES[cpu] if f not in dropped]

def _flag_key(copts):
    return "_".join([c.lstrip("-").replace("=", "_").replace("-", "_") for c in copts]) or "default"

def libgcc_cc_groups(objects):
    """Groups objects that share a part and compile flags.

    Each group becomes one cc_library. libgcc2.c objects get a wrapper source
    that defines L<name>, and objects with defines get a wrapper that defines
    them. Assembly objects with vis_hide get a wrapper that includes their hide
    list first in the static compile, as Makefile.in's -include $*.vis does.
    Their sources are also listed under hide, so that the hide list can be made
    from a -DSHARED compile.

    Returns:
      A list of structs with the group's name, part, asm, vis_hide, copts, srcs,
      wrappers and hide fields.
    """
    groups = {}
    order = []
    for part, entries in [
        ("common", objects.common),
        ("static_only", objects.static_only),
        ("eh", objects.eh),
    ]:
        for e in entries:
            asm = e.src != None and e.src.endswith(".S")
            key = "{}{}{}_{}".format(
                part,
                "_asm" if asm else "",
                "" if e.vis_hide else "_novis",
                _flag_key(e.copts),
            )
            if key not in groups:
                groups[key] = struct(
                    name = key,
                    part = part,
                    asm = asm,
                    vis_hide = e.vis_hide,
                    copts = e.copts,
                    srcs = [],
                    wrappers = {},
                    hide = [],
                )
                order.append(key)
            group = groups[key]
            if e.src == None:
                group.wrappers[e.name + ".c"] = "#define L{} 1\n#include \"libgcc/libgcc2.c\"\n".format(e.name)
            elif e.defines:
                lines = []
                for define in e.defines:
                    name, _, value = define.partition("=")
                    lines.append("#define {} {}\n".format(name, value or "1"))
                group.wrappers[e.name + "." + e.src.rsplit(".", 1)[1]] = "".join(lines) + "#include \"{}\"\n".format(e.src)
            elif asm and e.vis_hide:
                group.wrappers[e.name + ".S"] = "#ifndef SHARED\n#include \"{}.vis\"\n#endif\n#include \"{}\"\n".format(e.name, e.src)
                group.hide.append(e.src)
            else:
                group.srcs.append(e.src)
    return [groups[k] for k in order]
