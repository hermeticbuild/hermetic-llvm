# llvm-libgcc

Some artifacts built with this toolchain run on a Linux distribution as-is,
using that system's GNU core libraries (glibc, libstdc++ and libgcc_s).
llvm-libgcc lets such an artifact target the system's `libgcc_s` in two
respects:

- **The `NEEDED` entry.** The artifact depends on `libgcc_s.so.1`, the
  system's shared libgcc (unwinder plus compiler support routines), instead
  of the toolchain's default `libunwind.so.1`.
- **The symbol versions.** Its imports carry the `GCC_*` versions of the
  libgcc_s that belongs to the GCC release the platform selects for
  libstdc++, the same release whose `GLIBCXX_*` and `CXXABI_*` versions the
  artifact already targets. An artifact importing `__extendhfsf2@GCC_12.0.0`
  does not load on a distribution whose libgcc_s predates GCC 12; matching the
  libstdc++ release keeps the two in step.

#### TL;DR

With `--@llvm//config:experimental_use_llvm_libgcc=True`, on Linux glibc
x86_64 and aarch64 targets:

- `libgcc_s.so.1` is built here, from libunwind and the compiler-rt builtins
  with the soname `libgcc_s.so.1`.
- Its linker version script is generated from the libgcc sources of the GCC
  release the platform selects, by the same steps and the same
  `mkmap-symver.awk` GCC uses to build its own `libgcc_s.so`, so the
  exported symbols carry that release's `GCC_*` versions.
- It replaces `libunwind.so.1` as the dynamic unwinder: whatever links the
  C++ runtime dynamically depends on `libgcc_s.so.1` instead.

## What upstream llvm-libgcc does

[llvm-libgcc](https://github.com/llvm/llvm-project/tree/main/llvm-libgcc)
exists for a Linux distribution that wants to ship the LLVM runtimes as its
system libgcc, with no GCC at all. That is hard because `libgcc_s.so.1` is a
fixed name on such a system: it is required by the Linux Standard Base, and
glibc itself `dlopen`s it by name (for `backtrace`, among others). If the
system's actual unwinder is libunwind under its own name, glibc's calls land
in a second unwinder and the two cross-talk, which ends in crashes. So
upstream gives libunwind and compiler-rt a libgcc "front": the LLVM runtimes
presented under libgcc's names and ABI, so that everything on the system,
GCC-built binaries included, resolves to the one implementation.

It has two limitations for our purpose:

- **The `NEEDED` entry.** The library's soname stays `libunwind.so.1`; only
  the file names are libgcc's. A binary linked against it therefore records
  `NEEDED libunwind.so.1`, not `libgcc_s.so.1`, and does not load on a system
  that only has GCC's libgcc.
- **The symbol versions.** `gcc_s.ver.in` is one hand-maintained snapshot,
  taken from a particular `libgcc_s.so.1` at generation time and the same for
  every GCC release. Versions newer than the snapshot are missing
  (`GCC_12.0.0`, `GCC_13.0.0`, ...), so an artifact cannot target a newer
  distribution's libgcc_s, and there is no way to pair a libstdc++ platform
  with a libgcc_s of the same era.

## How this implementation resolves them

### The `NEEDED` entry

The library is built the way upstream llvm builds it, libunwind with the
compiler-rt builtins linked in and exported, but its soname is
`libgcc_s.so.1` rather than `libunwind.so.1` with symlinks. The soname is
what the linker copies into a binary's `NEEDED` entry, so a binary linked
against this library records `NEEDED libgcc_s.so.1`, and the target system's
libgcc satisfies it.

### The symbol versions

Instead of maintaining a snapshot, the version script is generated the way
GCC generates it for its own `libgcc_s.so`, from the sources of the GCC
release the platform selects. GCC keeps them as a generic list
(`libgcc/libgcc-std.ver.in`) plus per-target fragments under
`libgcc/config/`, every symbol under the version node it was introduced in,
and `libgcc/Makefile.in` turns them into the version script `libgcc.map` in
two steps:

1. **`libgcc.map.in`**: the generic list and the target's fragments are
   concatenated and run through the target preprocessor, resolving their
   `%ifdef __x86_64__`-style guards.
2. **`libgcc.map`**: `nm` lists the symbols of the objects being linked into
   `libgcc_s.so`, and GCC's `mkmap-symver.awk` combines that list with
   `libgcc.map.in`: it keeps only the symbols the objects define, resolves
   the version inheritance lines, drops version nodes left empty, and makes
   everything else local.

Running the same two steps, with the same GCC scripts, but with libunwind and
the compiler-rt builtins as the objects, yields a map with exactly the
symbols we define under the versions of the selected GCC release.

## The implementation

The libgcc_s symbol versions match the libstdc++ release the platform
selects: both come from the same GCC sources. The steps, each documented in
detail next to its code:

1. **Fetch the inputs.** The sparse GCC archive extraction in
   `3rd_party/gcc/extension/gcc.bzl` includes the libgcc version files and
   `mkmap-symver.awk`.
2. **`@gcc//:libgcc.map.in`.** `3rd_party/gcc/libgcc/libgcc_map_in.bzl`
   reproduces GCC's first step: it concatenates the generic list with the
   target's fragments (selected per CPU in `gcc.BUILD.bazel`, following
   `libgcc/config.host`) and runs the toolchain's preprocessor for the target.
3. **`libgcc.map`.** `libgcc_map.bzl` in this package reproduces GCC's second
   step: `llvm-nm` over the archives of `//libunwind` and
   `//compiler-rt:builtins`, then GCC's awk.
4. **`libgcc_s.so.1`.** `llvm-libgcc.BUILD.bazel` links libunwind and the
   builtins into one stage1 shared library with that map, `-lm` as upstream,
   and the soname `libgcc_s.so.1`, so that binaries record the `NEEDED` entry
   GCC-built binaries record. The builtins are recompiled for this library with
   default visibility (`//config:compiler_rt_builtins_hide_symbols` off) because
   hidden symbols can never be exported.

## Limits and follow-ups

- x86_64 and aarch64 glibc only: those are the targets `libgcc.map.in`
  declares mapfiles for. Adding a target means reading its `config.host`
  entry and fragments and extending the `select`; `libgcc_s.shared` is
  `target_compatible_with` the same set.
- `__cpu_indicator_init` and `__cpu_model` are named by the map but declared
  hidden in compiler-rt (`lib/builtins/cpu_model/x86.c`), so they stay local.
  GCC exports them only as a non-default version for binaries linked against
  GCC 4.8.
- compiler-rt has no compatibility `.symver` aliases, so the older versions of
  the six corrected symbols (`__divtc3@GCC_4.0.0`, `__gttf2@GCC_3.0`, ...)
  are absent; only their defaults exist.
- `config/aarch64/libgcc-softfp.ver` upstream names its node `GCC_11.0` but
  inherits `GCC_13.0.0` from `GCC_11.0.0`, which makes `GCC_13.0.0` a second
  base node. The awk reproduces what GCC itself produces from that file.
- `libgcc.a` and `libgcc_eh.a` are not provided, and `-lgcc_s` still resolves
  to the stub rather than to this library.
- `cc_shared_library`, and `cc_binary` with the default `linkstatic`, keep
  the static libunwind: the `cc_toolchain` runtime libraries follow the
  linking mode of the consuming target, and `cc_shared_library` always links
  statically. Letting the target platform decide instead is what the rules_cc
  C++ runtimes toolchain provides; adopting it is a separate change.
- The version nodes and symbol order in the map follow awk's array iteration
  order, as in GCC; they are deterministic for a given awk but can differ
  between execution platforms.
