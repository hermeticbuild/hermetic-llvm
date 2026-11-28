"""cc_binary for linux_x86_64_musl with @llvm//runtimes:exceptions off.

bazel_lib's platform_transition_binary only changes the platform; the test
also needs the runtimes' exceptions setting flipped in the same configuration,
so that the libc++ and libc++abi linked into the binary are the no-exceptions
variants. with_cfg is how the toolchain's own runtime rules do this.
"""

load("@rules_cc//cc:cc_binary.bzl", "cc_binary")
load("@with_cfg.bzl", "with_cfg")

_builder = with_cfg(cc_binary)
_builder.set(Label("@llvm//runtimes:exceptions"), False)
_builder.set("platforms", [Label("@llvm//platforms:linux_x86_64_musl")])

no_exceptions_runtimes_cc_binary, _no_exceptions_runtimes_cc_binary_internal = _builder.build()
