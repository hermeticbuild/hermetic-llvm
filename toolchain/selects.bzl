LLVM_VERSION = "22.1.4"

def platform_llvm_binary(binary):
    return select({
        "@llvm//platforms/config:macos_x86_64_prebuilt": "@llvm-toolchain-minimal-%s-darwin-amd64//:bin/%s" % (LLVM_VERSION, binary),
        "@llvm//platforms/config:macos_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-darwin-arm64//:bin/%s" % (LLVM_VERSION, binary),
        "@llvm//platforms/config:linux_x86_64_prebuilt": "@llvm-toolchain-minimal-%s-linux-amd64//:bin/%s" % (LLVM_VERSION, binary),
        "@llvm//platforms/config:linux_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-linux-arm64//:bin/%s" % (LLVM_VERSION, binary),
        "@llvm//platforms/config:windows_aarch64_prebuilt": "@llvm-toolchain-minimal-%s-windows-arm64//:bin/%s.exe" % (LLVM_VERSION, binary),
        "@llvm//platforms/config:windows_x86_64_prebuilt": "@llvm-toolchain-minimal-%s-windows-amd64//:bin/%s.exe" % (LLVM_VERSION, binary),
        "@llvm//toolchain:bootstrapped_toolchain": "@llvm//toolchain/bootstrap:" + binary,
    })

def platform_extra_binary(binary):
    return select({
        "@llvm//platforms/config:macos_x86_64": "@toolchain-extra-prebuilts-darwin-amd64//:%s" % binary,
        "@llvm//platforms/config:macos_aarch64": "@toolchain-extra-prebuilts-darwin-arm64//:%s" % binary,
        "@llvm//platforms/config:linux_x86_64": "@toolchain-extra-prebuilts-linux-amd64//:%s" % binary,
        "@llvm//platforms/config:linux_aarch64": "@toolchain-extra-prebuilts-linux-arm64//:%s" % binary,
        # TODO(zbarsky): should we suffix these with `.exe` in the dist?
        "@llvm//platforms/config:windows_aarch64": "@toolchain-extra-prebuilts-windows-arm64//:%s" % binary,
        "@llvm//platforms/config:windows_x86_64": "@toolchain-extra-prebuilts-windows-amd64//:%s" % binary,
    })

def platform_extra_binary_files(binary):
    return select({
        "@llvm//platforms/config:macos_x86_64": ["@toolchain-extra-prebuilts-darwin-amd64//:%s" % binary],
        "@llvm//platforms/config:macos_aarch64": ["@toolchain-extra-prebuilts-darwin-arm64//:%s" % binary],
        "@llvm//platforms/config:linux_x86_64": ["@toolchain-extra-prebuilts-linux-amd64//:%s" % binary],
        "@llvm//platforms/config:linux_aarch64": ["@toolchain-extra-prebuilts-linux-arm64//:%s" % binary],
        # TODO(zbarsky): should we suffix these with `.exe` in the dist?
        "@llvm//platforms/config:windows_aarch64": ["@toolchain-extra-prebuilts-windows-arm64//:%s" % binary],
        "@llvm//platforms/config:windows_x86_64": ["@toolchain-extra-prebuilts-windows-amd64//:%s" % binary],
    })

def _tool_repo(exec_os, exec_cpu):
    os_part = "darwin" if exec_os == "macos" else exec_os
    cpu_part = "amd64" if exec_cpu == "x86_64" else "arm64"
    return "@llvm-toolchain-minimal-%s-%s-%s//" % (LLVM_VERSION, os_part, cpu_part)

def platform_module_map(exec_os, exec_cpu):
    return _tool_repo(exec_os, exec_cpu) + ":module_map"

def resource_dir_arg(exec_os, exec_cpu):
    return _tool_repo(exec_os, exec_cpu) + ":compile_resource_dir"

def header_parser_arg(exec_os, exec_cpu):
    # Once rules_cc supports `env` on `cc_tool`, header-parser can become a singleton
    # tool and this per-toolchain args target can be cleaned up.
    return _tool_repo(exec_os, exec_cpu) + ":header_parser_args"

def static_library_validator_arg(exec_os, exec_cpu):
    # Once rules_cc supports `env` on `cc_tool`, static-library-validator can become
    # a singleton tool and this per-toolchain args target can be cleaned up.
    return _tool_repo(exec_os, exec_cpu) + ":static_library_validator_args"

def platform_cc_tool_map(exec_os, exec_cpu):
    tool_repo = _tool_repo(exec_os, exec_cpu)

    # Even though `tool_map` is exec-configured, this `select` happens under the target configuration.
    # That's because Bazel resolves the select before applying the exec transition, but if these targets
    # point at further aliases that use `select`, those will resolve according to the exec platform.
    # See https://github.com/bazelbuild/bazel/issues/27623#issuecomment-3529439585 for more details.
    return select({
        "@rules_cc//cc/toolchains/args/archiver_flags:use_libtool_on_macos_setting": tool_repo + ":tools_with_libtool",
        "//conditions:default": tool_repo + ":default_tools",
    })
