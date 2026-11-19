load("//platforms:common.bzl", "SUPPORTED_EXECS")

def _tool_repo(exec_os, exec_cpu):
    os_part = "darwin" if exec_os == "macos" else exec_os
    cpu_part = "amd64" if exec_cpu == "x86_64" else "arm64"
    return "@llvm-toolchain-minimal-%s-%s//" % (os_part, cpu_part)

def _platform_bootstrap_stage(exec_os, exec_cpu, bootstrap_stage):
    return "@llvm//platforms/config:%s_%s_%s" % (exec_os, exec_cpu, bootstrap_stage)

def platform_llvm_binary(binary):
    # Select the compiler generation requested by the bootstrap transition.
    # Stage 0 tools and resource headers come from one downloaded installation;
    # Stage 1/2/3 labels refer to source-built binaries whose matching resource
    # headers are materialized under their stage prefix by bootstrap toolchain
    # construction. Never pair the Stage 0 binary with headers from the source
    # tree currently being compiled.
    binaries = {
        _platform_bootstrap_stage(exec_os, exec_cpu, "stage0_prebuilt_seed"): Label(
            "%s:bin/%s%s" % (_tool_repo(exec_os, exec_cpu), binary, ".exe" if exec_os == "windows" else ""),
        )
        for exec_os, exec_cpu in SUPPORTED_EXECS
    }
    binaries["@llvm//toolchain:bootstrap_stage1_from_source"] = Label(
        "@llvm//toolchain/bootstrap/stage1:" + binary,
    )
    binaries["@llvm//toolchain:bootstrap_stage2_lto_and_fdo_instrumented"] = Label(
        "@llvm//toolchain/bootstrap/stage2:" + binary,
    )
    binaries["@llvm//toolchain:bootstrap_stage3_lto_and_fdo_applied"] = Label(
        "@llvm//toolchain/bootstrap/stage3:" + binary,
    )
    return select(binaries)

def platform_flang_binary():
    """Select the execution Flang from the chosen LLVM bootstrap generation.

    Returns:
        A select of the Flang executable for the execution platform and bootstrap stage.
    """
    binaries = {
        _platform_bootstrap_stage(exec_os, exec_cpu, "stage0_prebuilt_seed"): Label(
            "@flang-toolchain-minimal-%s-%s//:bin/flang%s" % (
                "darwin" if exec_os == "macos" else exec_os,
                "amd64" if exec_cpu == "x86_64" else "arm64",
                ".exe" if exec_os == "windows" else "",
            ),
        )
        for exec_os, exec_cpu in SUPPORTED_EXECS
    }

    # Flang has a source-backed ThinLTO build, but no Flang FDO profile. All
    # source bootstrap modes therefore select the same LTO executable.
    source_flang = Label("@llvm//prebuilt/flang:flang")
    for stage in [
        "bootstrap_stage1_from_source",
        "bootstrap_stage2_lto_and_fdo_instrumented",
        "bootstrap_stage3_lto_and_fdo_applied",
    ]:
        binaries["@llvm//toolchain:" + stage] = source_flang

    return select(binaries)

def platform_extra_binary(binary):
    return select({
        "@llvm//platforms/config:macos_x86_64": Label("@toolchain-extra-prebuilts-darwin-amd64//:%s" % binary),
        "@llvm//platforms/config:macos_aarch64": Label("@toolchain-extra-prebuilts-darwin-arm64//:%s" % binary),
        "@llvm//platforms/config:linux_x86_64": Label("@toolchain-extra-prebuilts-linux-amd64//:%s" % binary),
        "@llvm//platforms/config:linux_aarch64": Label("@toolchain-extra-prebuilts-linux-arm64//:%s" % binary),
        # TODO(zbarsky): should we suffix these with `.exe` in the dist?
        "@llvm//platforms/config:windows_aarch64": Label("@toolchain-extra-prebuilts-windows-arm64//:%s" % binary),
        "@llvm//platforms/config:windows_x86_64": Label("@toolchain-extra-prebuilts-windows-amd64//:%s" % binary),
    })

def platform_stage0_toolchain_target(name, default):
    """Selects a target of the Stage 0 toolchain for the current platform.

    Resolve this in the exec configuration to get the target of the compiler
    installation that runs the actions. Source-built bootstrap stages select
    the default.

    Args:
        name: The name of the target in the toolchain repository.
        default: The label to select for other bootstrap stages.

    Returns:
        A select of the target.
    """
    targets = {
        _platform_bootstrap_stage(exec_os, exec_cpu, "stage0_prebuilt_seed"): Label(
            "%s:%s" % (_tool_repo(exec_os, exec_cpu), name),
        )
        for exec_os, exec_cpu in SUPPORTED_EXECS
    }
    targets["//conditions:default"] = default
    return select(targets)

def platform_module_map(exec_os, exec_cpu):
    return Label(_tool_repo(exec_os, exec_cpu) + ":module_map")

def platform_resource_dir(exec_os, exec_cpu):
    return Label(_tool_repo(exec_os, exec_cpu) + ":builtin_resource_dir")

def platform_cc_tool_map(exec_os, exec_cpu):
    tool_repo = _tool_repo(exec_os, exec_cpu)

    # Even though `tool_map` is exec-configured, this `select` happens under the target configuration.
    # That's because Bazel resolves the select before applying the exec transition, but if these targets
    # point at further aliases that use `select`, those will resolve according to the exec platform.
    # See https://github.com/bazelbuild/bazel/issues/27623#issuecomment-3529439585 for more details.
    return select({
        "@llvm//platforms/config:wasi_components": Label(tool_repo + ":wasi_component_tools_for_runtime"),
        "@platforms//os:uefi": Label(tool_repo + ":uefi_tools"),
        "@llvm//platforms/config:windows_x86_64_msvc": Label(tool_repo + ":tools_for_msvc_for_runtime"),
        "@llvm//platforms/config:windows_aarch64_msvc": Label(tool_repo + ":tools_for_msvc_for_runtime"),
        "@llvm//platforms/config:windows_x86_64_mingw_compatible": Label(tool_repo + ":tools_for_mingw_for_runtime"),
        "@llvm//platforms/config:windows_aarch64_mingw_compatible": Label(tool_repo + ":tools_for_mingw_for_runtime"),
        "@llvm//toolchain:linux_complete": Label(tool_repo + ":tools_with_interface_libraries"),
        "@llvm//toolchain:macos_complete_with_libtool": Label(tool_repo + ":tools_with_dsym_and_libtool"),
        "@llvm//toolchain:macos_complete": Label(tool_repo + ":tools_with_dsym"),
        "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_apple_setting": Label(tool_repo + ":tools_with_libtool_for_runtime"),
        "//conditions:default": Label(tool_repo + ":default_tools_for_runtime"),
    })
