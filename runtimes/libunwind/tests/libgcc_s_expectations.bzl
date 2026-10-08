# What libgcc_s.so.1 must export for a GCC version and target, following the
# version nodes of libgcc/libgcc-std.ver.in and the target fragments GCC
# builds the map from, restricted to symbols libunwind and compiler-rt define.

load("//3rd_party/gcc:version.bzl", "gcc_version_at_least_for")

def _versioned(symbol, version):
    # The default version of a symbol, as llvm-readelf --dyn-syms prints it.
    return symbol + "@@" + version  # buildifier: disable=canonical-repository

def libgcc_s_expectations(arch, version):
    versions = [
        "GCC_3.0",
        "GCC_3.3",
        "GCC_3.3.1",
        "GCC_3.4",
        "GCC_3.4.2",
        "GCC_3.4.4",
        "GCC_4.0.0",
        "GCC_4.2.0",
        "GCC_4.3.0",
        "GCC_7.0.0",
    ]
    forbidden = []
    symbols = [
        _versioned("_Unwind_Resume", "GCC_3.0"),
        _versioned("_Unwind_RaiseException", "GCC_3.0"),
        _versioned("__udivti3", "GCC_3.0"),
        _versioned("_Unwind_Backtrace", "GCC_3.3"),
        _versioned("__gcc_personality_v0", "GCC_3.3.1"),
        _versioned("__popcountdi2", "GCC_3.4"),
        _versioned("__enable_execute_stack", "GCC_3.4.2"),
        _versioned("__absvti2", "GCC_3.4.4"),
        _versioned("__divdc3", "GCC_4.0.0"),
        _versioned("_Unwind_GetIPInfo", "GCC_4.2.0"),
        _versioned("__emutls_get_address", "GCC_4.3.0"),
        _versioned("__divmodti4", "GCC_7.0.0"),
    ]

    if arch == "x86_64":
        # config/i386/libgcc-glibc.ver: GLIBC_2.0 is i386 only, and the
        # _Float16 and __bf16 helpers came with GCC 12 and 13.
        forbidden.append("GLIBC_2.0")
        symbols.append(_versioned("__register_frame", "GCC_3.0"))
        symbols.append(_versioned("__divtc3", "GCC_4.3.0"))
        if gcc_version_at_least_for(version, "12.0.0"):
            symbols.append(_versioned("__extendhfsf2", "GCC_12.0.0"))
            symbols.append(_versioned("__truncdfhf2", "GCC_12.0.0"))
        else:
            forbidden.append("GCC_12.0.0")
        if gcc_version_at_least_for(version, "13.0.0"):
            symbols.append(_versioned("__truncsfbf2", "GCC_13.0.0"))
        else:
            forbidden.append("GCC_13.0.0")
    elif arch == "aarch64":
        # config/libgcc-glibc.ver makes GLIBC_2.0 the base version, and
        # config/aarch64/libgcc-softfp.ver (GCC 11+) adds the _Float16 helpers
        # as GCC_11.0 and the __bf16 helpers as GCC_13.0.0.
        versions.append("GLIBC_2.0")
        symbols.append(_versioned("__register_frame", "GLIBC_2.0"))
        symbols.append(_versioned("__addtf3", "GCC_3.0"))
        if gcc_version_at_least_for(version, "11.0.0"):
            symbols.append(_versioned("__extendhftf2", "GCC_11.0"))
        else:
            forbidden.append("GCC_11.0")
        if gcc_version_at_least_for(version, "13.0.0"):
            symbols.append(_versioned("__truncsfbf2", "GCC_13.0.0"))
        else:
            forbidden.append("GCC_13.0.0")
    else:
        fail("no libgcc_s expectations for " + arch)

    return {
        "EXPECTED_SYMBOLS": " ".join(symbols),
        "EXPECTED_VERSIONS": " ".join(versions),
        "FORBIDDEN_VERSIONS": " ".join(forbidden),
    }
