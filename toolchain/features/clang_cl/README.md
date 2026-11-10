# clang-cl feature protocol

This package contains the downstream rules_cc feature implementations needed
when the C++ driver speaks clang-cl's CL-compatible command-line and response
file protocol. It does not own the Windows MSVC target ABI, Microsoft SDK or
runtime closure, CRT selection, or COFF artifact naming.

hermetic-llvm composes this package only into its fixed LLVM-family Windows
route: clang-cl compiles and drives links, lld-link links PE/COFF outputs, and
llvm-lib creates archives. The package therefore also contains the narrow
clang-cl-to-lld-link bridge needed to render structured libraries and COFF
ThinLTO options. That bridge is intentional; it is not a promise that the
driver, linker, or target format can be selected independently in this
repository.

Prefer CL options when they express the intended policy exactly, then Clang
extensions accepted directly by clang-cl. Use `/clang:` only when CL parsing
would reject the option or give it a different meaning. clang-cl appends all
`/clang:` arguments after the ordinary arguments: it is not position-preserving.
Use direct warning options so later target-local suppressions can override
defaults. See the
[clang-cl manual](https://clang.llvm.org/docs/UsersManual.html#the-clang-option).

Bazel response files put each argument on a separate line. clang-cl cannot
consume a separate `-Xclang` or `-Xlinker` value across those line boundaries.
Use joined `-Xclang=...` for frontend options. There is no corresponding
clang-cl `-Xlinker=...` option, so COFF options still require `/clang:-Xlinker`.
Forward the entire library input sequence through `/clang:`, including
`/start-lib`, its object paths, `/end-lib`, and ordinary archives. This preserves
both lazy library membership and symbol selection between libraries.
`/link` is not a replacement:
it consumes subsequent arguments and the driver emits its values before inputs.

Some spellings that look interchangeable are not:

- `/W3` maps to Clang's `-Wall`; bare `-Wall` means `/Wall` (`-Weverything`).
- `/X` aliases `-nostdlibinc`, retaining builtin and explicit `/imsvc` headers.
- `/Ot` and `/Os` select LLVM O3 and size optimization. `/O2` also selects O3,
  while `/O1` selects size optimization and both add other CL policy. Exact
  LLVM O1, O2, Og, and Oz levels still need `/clang:`. To override those levels,
  a user must also use `/clang:` (for example `/clang:-O0`, not `/Od`).
- `/GR-` disables RTTI data only; `no_rtti` requires `/clang:-fno-rtti`.
- `/Oy` and `/Oy-` cannot implement our frame-pointer policy on x64.
- `/MD` selects the CRT; `/clang:-MD` and `/clang:-MF` generate dependency files.
- libc++ wrappers must precede builtin headers, so their `-isystem` cannot be
  replaced with `/imsvc`. Keep the frontend-only `-ivfsoverlay` separate from
  linker overlays, too.

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

Module maps, layering checks, and header parsing are not implemented for this
protocol yet. Their names are temporarily tolerated because the repository's
shared e2e configuration requests `layering_check`; the empty registration is
not a support claim and must be replaced by dialect-correct actions.
