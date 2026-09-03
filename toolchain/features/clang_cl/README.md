# clang-cl feature protocol

This package contains the downstream rules_cc feature implementations needed
when the C++ driver speaks clang-cl's CL-compatible command-line and response
file protocol. It does not own the Windows MSVC target ABI, Microsoft SDK or
runtime closure, CRT selection, or COFF artifact naming.

hermetic-llvm composes this package only into its fixed LLVM-family Windows
route: clang-cl compiles and drives links, lld-link links PE/COFF outputs, and
llvm-ar creates archives. The package therefore also contains the narrow
clang-cl-to-lld-link bridge needed to render structured libraries and COFF
ThinLTO options. That bridge is intentional; it is not a promise that the
driver, linker, or target format can be selected independently in this
repository.

Treat target OS, target ABI/object format, runtime, and compiler personality as
distinct semantic axes, even where the supported route makes them one-to-one.
The OS owns Windows platform conventions shared by its toolchain routes; the
ABI/object format owns calling conventions and PE/COFF link and artifact
semantics; the runtime owns CRT and C++ runtime inputs and linkage policy; the
compiler personality owns command spelling and action protocol (`clang` versus
`clang-cl`). Compose those axes at the toolchain route boundary rather than
making a lower-level argument infer one from another. Only an explicitly named
bridge should combine axes when one tool's protocol must transport another
tool's semantics, as clang-cl does for lld-link here.

The package is intentionally temporary. These implementations should be
upstreamed to rules_cc rather than remain a hermetic-llvm-specific adapter.
The upstream package shape is intentionally undecided. What is proved here is
that toolchain assembly must choose the implementation from an explicit
compiler-personality input: a feature used to define the current C++ toolchain
cannot itself consult that toolchain's compiler setting without creating a
dependency cycle. The lld-link/COFF ThinLTO and library bridge must remain
visibly constrained to that linker/toolchain capability rather than being
assumed for every clang-cl toolchain.

This protocol implements Bazel C++ header module maps and `layering_check` by
transporting the required Clang frontend arguments through clang-cl's
`/clang:` spelling. That support enforces direct-dependency header layering; it
also implements `parse_headers` with an execution-platform wrapper that creates
Bazel's processed-header marker before running clang-cl in syntax-only mode.
clang-cl reparses `/clang:` operands after its CL arguments, so language
selection uses the native global `/TP` and `/TC` switches rather than
position-sensitive transported `-x` options. Parsing defaults to C++;
`parse_headers_as_c` selects C17 for configurations containing C-only headers.
None of these features enable C++20 named modules, which remain unsupported.
