# Clang header modules

With Bazel 9.3 or later, enable module consumption with
`--features=use_header_modules`. Libraries whose headers can be compiled
standalone opt into producing modules with `features = ["header_modules"]`.
Both features can also be set on a package. A target can opt out entirely with
`features = ["-use_header_modules"]`.

The two features are intentionally independent, following the
[Android NDK toolchain](https://github.com/bazelbuild/rules_android_ndk/blob/8ba0720dcf044fc1cdd82ca8160df0dd394f8711/ndk_cc_toolchain_config.bzl#L538-L573).
Forcing `header_modules` globally also makes libraries with non-standalone
headers produce modules; for example, zlib includes `inffixed.h` inside a
function and cannot import that header as a module there.

On libc++ platforms, the C++ runtime toolchain adds a dependency on the libc++
header module to rules_cc targets. Implementation headers and C wrappers remain
textual. Bazel 8 continues to use textual standard-library headers.

Custom rules that call `cc_common.compile` must supply the appropriate runtime
and header dependencies themselves. A transitive dependency through a textual
library does not make all its dependency module maps directly available. For
example, protobuf 33.4's core runtime builds with `use_header_modules`, but its
generated well-known-type modules can absorb libc++ and Abseil headers textually
and fail with conflicting definitions when imported together.

Module compilation and consumption must agree on language options. Targets
with local `-std=` or `-fno-exceptions` settings that differ from the global
configuration need to disable `use_header_modules`. Windows header modules
remain unsupported.

Module code generation is a separate opt-in through
`header_modules_codegen_functions` or `header_modules_codegen_debuginfo`.
It can move hidden template instantiations into a module's object file;
consumers in another shared library may then fail to link. Keep such code
within one linkage unit or disable module code generation for that library.
