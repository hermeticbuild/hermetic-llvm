# LLVM libc: findings and proposed integration

Status: investigation and discussion only, 2026-11-11. No implementation or
public API is approved by this document.

Repository baseline: `8a3f5bd77702fc0de58252e715404fcac1eed24e`.
LLVM baseline: `23.1.2`, upstream commit
`85ac560262434c9ccfc0c183ec22d4138ed647fb` (`llvmorg-23.1.2`).
The repository currently selects the `llvm-23.1.2-3` compiler prebuilts.
Source links below use this release tag unless explicitly described as current
documentation. A release's architecture list, installed headers, entrypoint
selection, and implementation must be checked together.

## Recommendation and decisions

LLVM libc is a plausible **experimental static Linux C runtime option**, first
for x86_64, followed by AArch64 and RISC-V 64 after separate qualification.
It is not presently a justified replacement for every libc/toolchain combination
supported by hermetic-llvm. In particular, compiling a libc archive, accepting
a target triple, and running ordinary C++ applications are different milestones.

The first implementation unit should be a **private, source-built x86_64 runtime
slice at LLVM 23.1.2**: generated public headers, the upstream-selected source
closure, allocator, startup objects, compiler-rt builtins, and a static C fixture.
Keep it outside normal platform selection until its action graph and executable
have been inspected and run. Start with non-PIE executables; the existing musl
PIE policy is not evidence that LLVM libc has the same startup contract.

Before that work starts, agree on these decisions:

| Decision | Recommendation | Reason / gate |
| --- | --- | --- |
| Initial product | Experimental hosted C on Linux, static non-PIE | Smallest useful end-to-end contract; excludes unproved loader and C++ behavior. |
| First architecture | x86_64, then AArch64, then riscv64 | All three have Linux startup implementations; their API manifests still differ. |
| LLVM versions | Qualify 23.1.2 first; fail clearly for unqualified versions | Existing 21/22 support does not imply compatible libc generation or APIs. Development LLVM 24 needs a separate check. |
| Build strategy | Reuse suitable upstream Bazel definitions; fill full-runtime gaps against a CMake reference build | Fits current runtime/remote-execution architecture without duplicating the whole source graph; preserve upstream source selection and packaging semantics. |
| Header generation | Reuse pinned upstream Python headergen with a hermetic exec interpreter and PyYAML, subject to approval of this dependency path | `rules_python` already exists, but PyYAML and consumer-time header generation add a real dependency/maintenance cost. |
| Allocator | Initially qualify upstream Scudo standalone integration | A hosted archive built without Scudo does not automatically supply malloc/free. Do not silently reuse an unrelated allocator. |
| Public selection | Proposal only: existing libc constraint dimension, with an `llvm` value and only qualified Linux platforms | Exact names, visibility, supported versions, and C-only semantics require Corentin's explicit approval. No new module extension by default. |
| C++ | Separate opt-in milestone after an actual dependency/API audit | libc++ configuration and runtime routing currently assume other libcs; upstream demonstrations do not establish general support. |
| Compiler execution libc | Preserve current execution compiler platforms | Targeting LLVM libc must not switch the compiler, generators, or FDO training executables to LLVM libc. |

An implementation go-ahead must distinguish permission for the private proof
from approval of a public API. Candidate labels in this plan are discussion
examples, not labels that exist or an invitation to introduce them implicitly.

## What upstream support actually means

LLVM libc has several substantially different consumption models:

| Model | Meaning | Relevance here |
| --- | --- | --- |
| Full build | Own public C headers, ABI types, entrypoints, and applicable startup; Linux still needs target UAPI headers and allocation support | The model required for a selectable replacement libc. "Full" describes the build mode, not complete POSIX or application coverage. |
| Overlay | Selected LLVM implementations supplement an existing libc | A separate performance/experimentation feature; does not eliminate glibc, musl, Apple, or Microsoft runtime requirements. |
| Hand-in-Hand | Shared implementation support between LLVM libc and libc++ | Already used by this repository. Its internal headers are not an installed C SDK. |
| Bare metal | Target-specific freestanding library subset; board/application owns additional runtime services | Separate startup, allocation, I/O, linker-script, ISA, and ABI contract. |
| GPU | AMDGPU/NVPTX device libraries and, for some operations, host RPC support | Not a Linux host-libc choice and not a new supported GPU toolchain merely because a backend is available. |
| UEFI | Firmware-specific libc/startup | A separate candidate integration with a different entrypoint and driver contract. |

The [current full-host guide](https://libc.llvm.org/full_host_build.html) explicitly
warns about missing application-critical functions. The
[current platform policy](https://libc.llvm.org/platform_support.html) prioritizes
Linux, describes partial and non-continuously-tested macOS/Windows support, and
ties Linux support to maintained kernels rather than a glibc-style historical
ABI floor. The [architecture list](https://libc.llvm.org/arch_support.html) includes
ARM and GPU architectures, but does not promise every architecture/OS/API tuple.

The pinned [library packaging](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/lib/CMakeLists.txt)
distinguishes full-build `libc.a`, `libm.a`, optional `libmvec.a`, and overlay
`libllvmlibc.a`. On Linux it also creates a compatibility `libpthread.a`.
Do not copy musl's larger list of empty `dl`, `rt`, `resolv`, etc. archives unless
the corresponding LLVM libc behavior is actually provided.

### Supported-target intersection

The local target inventory is owned by
[`platforms/common.bzl`](../platforms/common.bzl), not by the set of LLVM
backends. The following assesses libc integration, not existing compiler support.

| Existing hermetic-llvm target family | LLVM libc evidence / gap | Proposed treatment |
| --- | --- | --- |
| Linux x86_64 | Pinned entrypoint/header lists and Linux startup exist; broad C subset, threads and TLS implementation | First experimental hosted-C target. |
| Linux AArch64 | Pinned entrypoint/header lists and startup exist; API selection differs from x86_64, notably locale | Second target, with independent manifest and execution checks. |
| Linux riscv64 | RISC-V config/startup exist; repo currently fixes rv64gc/lp64d | Third target; confirm ISA, ABI, TLS, atomics, and native/emulated runtime behavior. |
| Linux armv7 | ARM config exists, but no pinned `startup/linux/arm`; much smaller hosted entrypoint list | Do not publish hosted support from architecture coverage alone. Separate bring-up or limited-library proposal. |
| Linux s390x | No s390 Linux config/startup in the pinned tree | Unsupported for this feature; an upstream port would be separate work. |
| macOS x86_64/AArch64 | Partial upstream implementation does not replace libSystem, dyld, SDK/framework contracts | Preserve Apple SDK route. Overlay work, if desired, is separate. |
| Windows GNU/MSVC x86_64/AArch64 | Partial upstream implementation is not a replacement for MinGW/UCRT/VCRuntime/Windows SDK contracts | Preserve both existing ABI routes. clang-cl being an available driver changes none of this. |
| UEFI x86_64 | Upstream firmware libc exists; current docs describe early bring-up and x86_64 support | Separate experiment, not part of Linux rollout. Resolve startup ownership and entrypoint names first. |
| UEFI AArch64 | Existing local target does not establish upstream LLVM libc firmware support | Exclude until pinned upstream implementation and runtime evidence exist. |
| BPF, bare wasm32/wasm64 | No matching full libc configuration established | Keep freestanding routes; do not attach a host libc. |
| WASI wasm32 P1/threads/P2/P3 | Existing wasi-libc and component contracts are distinct | Keep wasi-libc. No substitution inferred from LLVM's wasm backend. |
| Bare-metal ARM/AArch64/RISC-V, AMDGPU/NVPTX | Upstream has dedicated models; these are not existing hosted target tuples here | Future independently scoped features and API approval. |

Pinned primary evidence:
[Linux configs](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.2/libc/config/linux),
[Linux startup](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.2/libc/startup/linux),
[ARM entrypoints](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/config/linux/arm/entrypoints.txt),
[UEFI config](https://github.com/llvm/llvm-project/tree/llvmorg-23.1.2/libc/config/uefi),
[cross-build models](https://libc.llvm.org/full_cross_build.html), and
[UEFI usage](https://libc.llvm.org/uefi/using.html).

### API and ABI boundaries that matter

- A listed symbol is not proof of implemented behavior. Pinned
  [`dlopen`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/src/dlfcn/dlopen.cpp)
  returns null unconditionally. Dynamic loading and a usable dynamic libc cannot
  be inferred from `dlfcn.h` or archive symbols.
- Pinned
  [`newlocale`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/src/locale/newlocale.cpp)
  and [`setlocale`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/src/locale/setlocale.cpp)
  implement limited C-locale behavior. The x86_64/RISC-V full manifests include
  locale entrypoints absent from the AArch64 manifest. Header/API capability must
  be assessed per architecture, not copied from x86_64.
- Regex and some other entrypoints sit behind the experimental-entrypoint switch.
  Do not enable all experimental functions merely to make a consumer link.
  Networking, resolver/NSS assumptions, process APIs, locale, wide characters,
  time zones, and pthread edge behavior need application-specific inventory.
- Treat LLVM libc's own headers/types as a distinct libc ABI. Do not mix glibc or
  musl objects that expose `FILE`, pthread types, errno/TLS, allocation ownership,
  or libc-private symbols with an LLVM-libc-linked process without demonstrated
  compatibility. The absence of GLIBC symbol versions is not sufficient proof.

## Repository ownership and required changes

This is an extension of existing toolchain contracts, not an existing bug fix.
The intended invariant is: selecting LLVM libc makes **all target C headers,
startup, builtins, allocation, and linked runtime dependencies coherent with
that target**, while execution tools retain their independently selected host
runtime. Unsupported combinations fail explicitly; they never borrow another
libc or host search path.

### Sources, generation, and Bzlmod

[`MODULE.bazel`](../MODULE.bazel), [`extensions/llvm.bzl`](../extensions/llvm.bzl),
and [`llvm_versions.json`](../llvm_versions.json) own the LLVM source selection.
The default is 23.1.2; existing patch/overlay branches cover 21, 22, 23 and an
experimental 24 route. Reuse this source identity for libc so headers, sources,
compiler-rt and C++ runtime configuration cannot drift independently. A new
libc download/version extension would add a needless compatibility axis unless
a concrete use case justifies it.

The current
[`x.x/libc/libc.BUILD.bazel`](../3rd_party/llvm-project/x.x/libc/libc.BUILD.bazel)
provides `libc_headers` for Hand-in-Hand and `shared_math_headers_for_apfloat`.
Neither builds a full C archive or generated public headers. Preserve these
targets and their callers; add runtime functionality with separate private
ownership instead of changing their meaning.

There is substantial upstream Bazel prior art: pinned
[`libc/BUILD.bazel`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/utils/bazel/llvm-project-overlay/libc/BUILD.bazel)
defines many per-function/support libraries, and
[`libc_build_rules.bzl`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/utils/bazel/llvm-project-overlay/libc/libc_build_rules.bzl)
provides a public-release-library helper and YAML header generation. Evaluate
reuse before authoring a parallel graph. It is not a ready-made hosted toolchain:
the inspected headergen macro does not filter declarations by selected
entrypoints, the release helper does not set `LIBC_FULL_BUILD`, and the package
does not provide the required hosted allocator/startup/pthread closure. Its
existing `@pyyaml` dependency also needs integration into this module's graph.
The local archive overlay currently replaces that upstream BUILD file, so reuse
requires a deliberate composition choice, not merely referencing an upstream
target that the default route has overwritten.

Source routes need explicit parity checks:

| Route | Current mechanism | Required proof |
| --- | --- | --- |
| Indexed/default archive | `private/llvm_project_archive.bzl` extracts redist sources, applies patches, then injects local runtime BUILD overlays | Redist archive contains the full required source/headergen/YAML/config closure; extract exclusions do not discard it. |
| Custom archive | Same repository rule, caller-provided source/integrity/options | Supported source layout/version diagnostics; override cannot silently select incompatible manifests. |
| `from_git` | `private/llvm_project_from_git.bzl` copies the upstream Bazel overlay | It does not install the same local runtime overlays automatically. Explicitly decide how the libc port becomes available here. |
| `from_path` | `private/llvm_project_from_path.bzl` symlinks source and upstream overlay | Same parity issue; generation must stay in Bazel outputs and must not write through source-directory symlinks. |

[`private/llvm_project_common.bzl`](../private/llvm_project_common.bzl) owns source
overlay and generated version files. Avoid broad normalization of these routes
as a prerequisite; document and test the exact supported route for the first
slice, then make the necessary narrow parity change.

Full-build public headers are generated from YAML using selected entrypoints.
Pinned
[`LLVMLibCHeaderRules.cmake`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/cmake/modules/LLVMLibCHeaderRules.cmake)
passes an entrypoint response file, generates public and proxy headers, and tracks
depfiles. `LLVM_LIBC_ALL_HEADERS` deliberately changes that contract. The Bazel
port must preserve target filtering, macro/type headers, and transitive YAML
inputs rather than glob all `.h` files or advertise every declaration.

Options for generation:

1. **Preferred:** upstream headergen as a normal hermetic exec tool, using the
   existing `rules_python` dependency and a pinned PyYAML dependency. All inputs
   declared; no host Python, pip install, repository-time compilation, network in
   actions, or target executable used as a generator. Verify both Python and
   PyYAML availability on all six execution OS/CPU combinations.
2. Pre-generated headers, per source revision and target manifest: avoids Python
   in consumer actions, but creates regeneration/review work and complicates
   arbitrary `from_git`/`from_path` sources. Accept only with an explicit supported
   revision contract and reproducible regeneration evidence.
3. Reimplement YAML/headergen in Starlark/C++: least attractive initially;
   duplicates upstream semantics and requires differential tests and maintenance.

The initial private slice should inventory the CMake dependency graph before
writing BUILD targets. Upstream
[`LLVMLibCObjectRules.cmake`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/cmake/modules/LLVMLibCObjectRules.cmake)
distinguishes internal and public entrypoint objects, aliases, external objects,
and public packaging. Merely compiling every `.cpp` would introduce duplicate
implementations, missing dependencies, or wrong exported names. Preserve the
entrypoint/config/CPU-feature selection from the pinned CMake files and compare
the resulting public symbol inventory with a reference build.

### Platform selection and target identity

[`constraints/libc/libc_versions.bzl`](../constraints/libc/libc_versions.bzl)
currently enumerates musl and glibc variants.
[`platforms/declare_platforms.bzl`](../platforms/declare_platforms.bzl) expands
every libc across five Linux CPUs, with only a glibc-version exception.
[`platforms/config/declare_config_settings.bzl`](../platforms/config/declare_config_settings.bzl)
generates matching settings. **Adding `llvm` to `LIBCS` alone would advertise
unqualified ARMv7 and s390x platforms.** A capability filter, shared by relevant
consumers, is required before publishing the new value.

Audit all `LIBCS` consumers, including compiler-rt's internal-symbolizer platform
generation; the same Cartesian-product assumption appears outside platforms.
Leave existing unconstrained/default-glibc behavior unchanged. Unsupported
user-defined OS/CPU/libc combinations need a deliberate error, not an accidental
fallthrough to GNU resource paths.

[`toolchain/args/llvm_target_triple.bzl`](../toolchain/args/llvm_target_triple.bzl)
owns compiler target triples;
[`runtimes/resource_directory.bzl`](../runtimes/resource_directory.bzl) owns
canonical runtime-directory triples. Both must agree. The latter currently has
generic Linux-to-GNU fallbacks, so changing the compiler triple alone can place
builtins in a directory the driver does not search.
[`toolchain/cc_toolchain.bzl`](../toolchain/cc_toolchain.bzl) separately selects
the `target_libc` identity and currently rejects a new LLVM libc choice; this
selection needs an explicit branch too.

The existing scoped registration extension,
[`extensions/toolchain.bzl`](../extensions/toolchain.bzl), selects OS/CPU pairs,
not libc. Stage 0 and bootstrap registrations can keep that model if libc is
selected by the target platform. Test both `@llvm//toolchain:all` and
`@llvm_toolchains//:all`. Preserve the baseline's lazy source-fetch behavior:
registration alone must not force downloading/building libc sources.

### Headers, kernel, and module maps

Linux C-header composition occurs in
[`toolchain/BUILD.bazel`](../toolchain/BUILD.bazel) and the staged counterpart
[`toolchain/runtimes/BUILD.bazel`](../toolchain/runtimes/BUILD.bazel).
Concrete libc-specific arguments belong below
[`toolchain/args/linux`](../toolchain/args/linux/BUILD.bazel), following the
semantic ownership in [`toolchain/README.md`](../toolchain/README.md): libc header
paths, startup paths, default libraries, and linkage policy remain distinct.

Use declared generated public headers and target Linux UAPI inputs. Keep the
compiler's own resource headers matched to the selected execution compiler
generation, as documented in
[`toolchain/bootstrap/README.md`](../toolchain/bootstrap/README.md).
An internal libc source-root include path may be necessary to build libc;
it must not become a broad consumer system-header path. Preserve C++ wrapper
ordering when C++ is eventually enabled.

[`kernel/extension/libc_kernel_versions.bzl`](../kernel/extension/libc_kernel_versions.bzl)
has libc-derived defaults but no LLVM libc entry. Select an explicit maintained
kernel baseline with the existing kernel constraint/configuration mechanism,
then test minimum runtime kernel behavior separately. New UAPI headers do not
guarantee old-kernel runtime compatibility. Do not inherit glibc 2.28's header
floor or host `/usr/include` by accident.

The reference cross-build exposed a path subtlety: pinned CMake emits
`-idirafter=${LIBC_KERNEL_HEADERS}` in this mode. With UAPI at
`$SYSROOT/include`, an absolute host path in that option was sysroot-prefixed
again by Clang; `/include` was the correct sysroot-relative spelling for this
layout. Inspect the emitted compiler arguments rather than copying a native
CMake recipe's header path.

[`toolchain/llvm/llvm.bzl`](../toolchain/llvm/llvm.bzl) builds the toolchain header
inventory/module maps, and [`runtimes/module_map.bzl`](../runtimes/module_map.bzl)
consumes files/tree artifacts. Add generated libc headers there too. Check
layering-check and header parsing inputs; do not disable them globally to hide
missing declarations. Reject unqualified header-module modes until checked.

### Runtime staging, builtins, allocator, and startup

Compiler bootstrap stages and target runtime stages are independent dimensions.
[`toolchain/BUILD.bazel`](../toolchain/BUILD.bazel) defines target runtime stages:
`stage0` for low-level runtime construction, `stage1`/`stage1_hosted` for higher
runtime work, and `complete` for applications.
[`with_cfg_runtimes_common.bzl`](../toolchain/runtimes/with_cfg_runtimes_common.bzl)
resets user flags and sanitizers; use this boundary rather than inventing another
bootstrap system. LLVM libc is implemented largely in C++, but its low-level
build must not depend on the target libc++ it is meant to enable.

Pinned
[`LLVMLibCCompileOptionRules.cmake`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/cmake/modules/LLVMLibCCompileOptionRules.cmake)
defines full-build, freestanding, no-builtin, exception/RTTI, and per-entrypoint
CPU options. Carry the relevant semantics into runtime rules. Do not inherit
host feature detection or `-march=native`; selected math/string implementations
must run on the declared target CPU baseline.

The dependency order to demonstrate is:

```text
exec compiler + exec headergen
  -> target public/internal headers + target UAPI
  -> compiler-rt builtins / libc support objects / allocator objects
  -> libc/libm archives + target startup
  -> C executable
  -> [later] libunwind -> libc++abi -> libc++ -> C++ executable
```

The diagram is a contract to verify, not proof that existing rules already
produce this graph. In particular,
[`compiler-rt.BUILD.bazel`](../3rd_party/llvm-project/x.x/compiler-rt/compiler-rt.BUILD.bazel)
selects libc headers for builtins and higher runtimes using GNU/musl branches;
these must be extended even for the smallest C program. Keep the builtins
header dependency acyclic. Avoid having the compiler tool's resource-directory
construction recursively request the complete libc being built.

Allocation is a first-class decision. Pinned
[`stdlib/CMakeLists.txt`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/src/stdlib/CMakeLists.txt)
models hosted malloc/calloc/realloc/aligned_alloc/free as external entrypoints;
with Scudo enabled it adds standalone Scudo objects and C wrappers. Disabling
Scudo leaves external allocation to be supplied. The existing optional
`-fsanitize=scudo` path is not automatically the correct libc allocator assembly.
Match `RUNTIMES_USE_LIBC=llvm-libc` configuration, avoid libc++/libunwind recursion,
disable optional GWP-ASan initially, and inspect unresolved symbols and link
ordering. An alternate allocator would require its own ABI/lifecycle proof.

[`runtimes/BUILD.bazel`](../runtimes/BUILD.bazel) currently assembles Linux CRTs
from glibc/musl startup plus synthetic empty `crti.o`/`crtn.o` and compiler-rt
crtbegin/crtend variants. LLVM libc supplies its own startup composition:
[`startup/linux/CMakeLists.txt`](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libc/startup/linux/CMakeLists.txt)
relocatable-links architecture start code, relocation support, and common process
initialization into `crt1.o`, and installs its own crti/crtn. Select that contract
explicitly; do not accidentally keep the synthetic objects or rename `crt1.o`
to `Scrt1.o`/`rcrt1.o` without proving the required behavior.

Startup tests must cover argc/argv/envp, auxiliary-vector use, initialized and
zeroed TLS, errno, constructors, atexit/destructors, exit status, stack alignment,
and thread creation. A successful `main() { return 0; }` does not exercise most
of this contract.

### Driver and linker behavior

The upstream full-host guide uses `x86_64-unknown-linux-llvm`. Prefer this explicit
identity if the pinned compiler and every runtime-directory lookup agree; do
not encode LLVM libc as musl just to reuse selections. The
[pinned GNU driver](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/clang/lib/Driver/ToolChains/Gnu.cpp)
still owns ordinary ELF startup/default-library insertion, and the
[Linux driver](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/clang/lib/Driver/ToolChains/Linux.cpp)
still has ordinary dynamic-loader/search-path behavior.

A verified `llvm-23.1.2-3` Darwin AArch64 compiler was dry-run for x86_64 and
AArch64 Linux LLVM triples:

```sh
clang --target=x86_64-unknown-linux-llvm -### -x c /dev/null \
  -fuse-ld=lld -rtlib=compiler-rt -static -no-pie
```

It requested `crt1.o`, `crti.o`, `crtbeginT.o`, triple-keyed compiler-rt builtins,
`-lc`, `crtend.o`, and `crtn.o`; without a declared sysroot it also emitted
`-L/usr/lib`. Removing static/non-PIE options selected PIE startup and a glibc
dynamic-loader path. AArch64 behaved analogously. Triple acceptance alone is
therefore neither hermeticity nor LLVM-libc dynamic-link support.

Two linking implementations were exercised by the x86_64 reference probe:

| Approach | Advantage | Obligation |
| --- | --- | --- |
| Keep Clang insertion, supply precise declared CRT/library/resource directories | Closest to current GNU/musl integration; fewer manually duplicated link rules | Prove every inserted file and name resolves to the intended declared target input; enforce static/non-PIE policy and block dynamic fallbacks. |
| Suppress driver startup/default libraries and pass an explicit ordered link set | Makes the initially narrow static contract auditable | Correctly own CRT ordering, builtins and libc rescan/group semantics; preserve user `-nostdlib`, `-nostartfiles`, partial-link and freestanding semantics. |

Prefer the first approach: the reference fixture passed with canonical
compiler-rt CRT names and no GNU CRT aliases. Repeat that proof through Bazel's
declared artifact composition. The second is a demonstrated fallback for a
narrow explicit link, but would duplicate more driver policy. Keep the decision
local to the LLVM-libc variant. Existing
`-nostdlibinc`, empty-sysroot, `-B`/`-L`, resource-directory, `-rtlib=compiler-rt`
and `--unwindlib=none` ownership must remain coherent.

The current musl `static_link_executable` selects `-static-pie` for some PIC/PIE
configurations. Do not reuse it unchanged. Initially reject explicit PIE,
dynamic executables, and shared-library final links for the LLVM libc profile;
ordinary relocatable objects/static archives remain useful. PIC compilation
does not itself prove or require a working static-PIE runtime.

### C++ and optional features

[`runtimes/cxxstdlib/BUILD.bazel`](../runtimes/cxxstdlib/BUILD.bazel) selects Linux
libc++/libc++abi/libunwind largely by OS and C++ library constraint. Even
`nostdlibxx` leaves the separate static unwind selection in place. Therefore a
C-only rollout must prevent accidental C++/unwind graph construction through
toolchain runtime attributes; passing `-nostdlib++` alone is insufficient.
The API decision must explain what a `cc_binary` containing C++ does before C++
support is qualified: reject it clearly or require an explicitly agreed minimal
freestanding mode, rather than silently link against another libc.

The local
[`libcxx.BUILD.bazel`](../3rd_party/llvm-project/x.x/libcxx/libcxx.BUILD.bazel)
hardcodes `_LIBCPP_LIBC_LLVM_LIBC` to zero for LLVM 23, enables localization,
filesystem, random-device, wide characters and threads, and selects GNU/musl
headers. Pinned libc++ has an
[`llvm_libc.h` locale adapter](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/libcxx/include/__locale_dir/support/llvm_libc.h),
but it uses limited/no-locale helpers; that is not full localization support.
The [current complete-runtimes recipe](https://libc.llvm.org/complete_runtimes_build.html)
starts from [an open demo-stubs change](https://github.com/llvm/llvm-project/pull/234353),
unmerged when inspected. Do not represent that recipe as an unpatched release
qualification. Audit libc++abi and libunwind too, including exceptions, TLS,
`dl_iterate_phdr`, constructor/destructor ordering and static archive extraction.
libstdc++ remains explicitly unsupported until independently qualified.

Other default/optional paths require a capability policy:

| Path | Initial policy and later evidence |
| --- | --- |
| compiler-rt builtins, stack-protector calls, atomic helpers | Needed subset must work; inspect undefined symbols and emitted instructions. Do not disable protection globally to hide a missing runtime. |
| Scudo allocator | Qualify as libc's allocator; separate from enabling sanitizer instrumentation on applications. |
| ASan/LSan/TSan/MSan/HWASan/DFSan/diagnostic UBSan and other sanitizers | Reject unqualified selections. libc interceptors, TLS, symbolizers and ABI assumptions require dedicated runtime work. Trap-only UBSan can be assessed separately. |
| Coverage, `--fdo_instrument`, custom profile settings, XRay, libFuzzer | Reject initially; `runtimes:profile_runtime_enabled` can activate profile archives independently of a sanitizer flag. Test both built-in Bazel and repository settings. |
| ThinLTO/full LTO | First preserve baseline correctness without LTO, then test archive extraction, builtins/CRT ownership, and final executable behavior with LTO. |
| Header parsing, layering checks, header modules | Include generated headers in the toolchain inventory; qualify or reject unsupported modes explicitly. |
| OpenMP, offload, split stack, external consumers | Separate qualification; do not allow driver flags to pull an undeclared or incompatible host runtime. |

Use existing feature/analysis validation patterns where practical. No broad
feature disabling on unrelated platforms, and no new public switches merely
to bypass an ununderstood failure.

## Execution compilers, bootstrap, and distribution

All six execution tuples (Linux/macOS/Windows, x86_64/AArch64) can in principle
cross-compile the proposed Linux targets. This is an integration objective, not
a demonstrated matrix. Headergen and other tools execute on those platforms;
libc, UAPI, CRT and consumer objects target Linux. Native Windows execution must
also validate paths, parameter files, generated headers and symlinks/copies.

The following paths must remain distinct:

| Path | Scope of this feature |
| --- | --- |
| Downloaded Stage 0 compiler | Existing compiler executable/runtime retained; target libc built from selected source. Resource headers stay with this compiler archive. |
| Stage 1 compiler built from source | Build compiler using existing host libc/platform; use it to build LLVM-libc targets. Required when source/compiler compatibility exceeds the available seed. |
| Stage 2 instrumented compiler and FDO training | Host-side work; target libc selection must not retarget these executables. Training executes compiler processes, not arbitrary target programs. |
| Stage 3 compiler | Preserve current host ThinLTO/FDO policy; qualify target LLVM-libc actions under this compiler separately. |
| LLVM compiler itself linked against LLVM libc | A much larger application/runtime milestone, requiring C++, threads, filesystem/process and profiling support; excluded from initial rollout. |
| Cross-language link owners | rules_rust/rules_rs, Zig, Go/cgo, foreign-cc and standalone drivers require separate tests; their target triples or sysroot conventions may independently choose GNU/musl. |

Owners: [`toolchain/selects.bzl`](../toolchain/selects.bzl),
[`toolchain/declare_toolchains.bzl`](../toolchain/declare_toolchains.bzl),
[`toolchain/bootstrap/declare_toolchains.bzl`](../toolchain/bootstrap/declare_toolchains.bzl),
and [`toolchain/bootstrap/README.md`](../toolchain/bootstrap/README.md).
Linux bootstrap compiler platforms explicitly use musl. Preserve that setting.

[`prebuilt/llvm/llvm_release.bzl`](../prebuilt/llvm/llvm_release.bzl) currently
packages the Stage 3 multicall compiler, compiler resource headers, and selected
ignorelists; it does not package target libc sysroots. `prebuilt/extras` is also
an execution-tool bundle, not a target-runtime distribution. Source-built target
LLVM libc does not inherently require a compiler-prebuilt release.

If standalone crossenv distributions are desired later, define their contract
separately: target triple, libc headers, UAPI, libc/libm/allocator, startup,
compiler-rt, optional C++ runtimes, licenses/provenance, and compiler config/search
paths. Test relocated archives outside Bazel with an empty host include/library
environment. Do not add target archives to every execution compiler download by
default. Source/prebuilt manifests must identify LLVM revision and all libc
configuration/CPU/allocator choices; checksums alone do not describe ABI policy.

UEFI deserves its own decision: the pinned driver for
`x86_64-unknown-uefi-llvm` chooses lld-link and `EfiMain`, while this repository's
existing hybrid Windows-target UEFI route owns `efi_main` and its own flags.
Both startup and application entrypoint ownership must be reconciled before
using upstream firmware libc. Existing local AArch64 support is not evidence
that the upstream x86_64 firmware port covers it.

## Proposed implementation sequence

1. **Discussion gate:** agree on experimental C scope, allocator, generation
   dependency, first architecture/version, and the private-proof boundary.
   Record all public labels/options proposed for a later approval.
2. **Private source/runtime proof:** inventory pinned CMake source/dependency
   and header manifests; build the x86_64 slice using existing stage0 runtime
   machinery. Compare public headers, symbols, compile flags, CRT and link order
   with upstream. Run C fixtures. No default platform or release changes.
3. **Public API gate:** present exact constraint/platform names, C-only behavior,
   unsupported-feature diagnostics, kernel baseline, version policy and minimal
   usage example. Obtain explicit approval before introducing them.
4. **Narrow Linux integration:** wire semantic args, source overlays, target
   triples/resource layout, builtins, CRT, module maps, and feature guards.
   Preserve existing defaults and lazy registration. Add focused external-module
   E2E coverage; expand to AArch64/RISC-V only after passing their own checks.
5. **Execution/source matrix:** qualify six exec tuples, default/scoped
   registration, source overrides, and applicable bootstrap stages. A missing
   execution lane remains an explicit unsupported/unverified limitation.
6. **Separate extensions:** C++ runtime capabilities, PIE, sanitizer/profile/LTO
   combinations, cross-language consumers, UEFI, and packaged sysroots each need
   evidence and a scope decision. None is implied by a Linux C milestone.

## Acceptance and test matrix

No Bazel implementation exists in this change, so commands naming future
fixtures are not presented as runnable targets. Use the final approved labels
when implementing. All Bazel build/test/aquery/cquery checks default to
`--config=remote`; use isolated output bases for concurrent runs. Root and
`e2e/rules_cc` configurations were inspected. The latter enables layering checks
and uses a local module override plus scoped toolchain registration.

| Scenario | Required observable result |
| --- | --- |
| Baseline | Existing default/glibc/musl/macOS/Windows/WASI/UEFI fixtures unchanged; record `bazel build --config=remote //:main` in `e2e/rules_cc` before and after implementation. |
| Source/generated-header contract | Compare per-architecture declared header surface and source/entrypoint closure with pinned upstream; experimental declarations remain excluded by default. |
| Hermetic action graph | `aquery` compile/archive/link/generator actions: declared exec tools; target LLVM libc/UAPI only; no host Python, `/usr/include`, `/usr/lib`, GNU/musl libc, host CPU probing or undeclared network. |
| Runtime graph | `cquery`/`aquery`: no target libc++/unwind/profile or optional sanitizer runtime beyond the selected allocator for the initial C fixture; no cycle through resource directories; host tools keep their host platform/libc. |
| Archive identity | `llvm ar t`, `llvm nm` and symbol comparison: expected public names and allocator closure, no duplicate entrypoint variants; classify unresolved symbols rather than accepting archive creation alone. |
| Static executable | `llvm readelf -h -l -d -s`: correct machine/ABI, expected non-PIE type, no PT_INTERP/DT_NEEDED or GLIBC version dependency; link trace identifies intended CRT/libc/builtins. Then run and check behavior. |
| C lifecycle | argv/env, constructors, TLS initialization/zeroing and per-thread errno, malloc/realloc/alignment, stdio/file I/O, pthread create/join, atexit/destructors and exit code. Include failure returns/errno. |
| API boundaries | C-locale behavior and unsupported locale handling; dynamic-loading behavior documented without claiming loader support; missing/experimental APIs fail predictably. |
| Cross-target correctness | x86_64, AArch64, riscv64 separately: action triple, object machine, UAPI architecture, TLS/atomics, CPU baseline. Execute natively or with a declared emulator; link success is not runtime evidence. |
| Execution platforms | Linux/macOS/Windows x86_64/AArch64 compile same target fixtures. Native Windows checks generated paths/response files. Remote Linux execution cannot stand in for native Windows testing. |
| Build modes | Debug/optimized, ordinary PIC objects, no-LTO then ThinLTO; explicitly rejected PIE/dynamic/shared final links and unsupported feature combinations. Honor freestanding/nostdlib/nostartfiles boundaries. |
| Negative selection | Unsupported OS/CPU/libc, unqualified LLVM version, libstdc++, C++ before its milestone, sanitizers, coverage/FDO/profile, and unsupported module modes fail at a useful boundary. No silent GNU fallback. |
| Source routes/Bzlmod | Default archive, custom archive, pinned git and local path within declared support; minimal downstream module with non-dev dependency. Registration-only query remains lazy; source checkout remains unchanged. |
| Kernel | Explicit/default UAPI selection, maintained baseline runtime and a newer kernel; document minimum-kernel evidence separately from compile-header version. |
| Later C++ | Containers/allocation, exceptions across frames, RTTI, threads/TLS, static destruction, filesystem, locale/wide-char and consumer ABI checks under declared capabilities. Compare with pinned upstream tests. |
| Later distribution | Relocate/extract bundle, invoke standalone compiler with no host SDK/libc, inspect and run outputs; match Bazel behavior and provenance. |

Reuse and derive relevant tests from upstream `libc/test` and startup integration
tests rather than fabricating only a hello-world check. The upstream
[cross-build documentation](https://libc.llvm.org/full_cross_build.html) distinguishes
self-hosted full-build tests from ordinary `check-libc`, which can depend on
system C/C++ headers. Make that distinction in test results. For every discovered
integration bug, run the same reproducer on the unmodified implementation and
after the fix; inspect the changed action/artifact/protocol, not only exit status.

## Evidence obtained and remaining uncertainty

This investigation inspected the owning repository files above and pinned LLVM
23.1.2 source using GitHub's contents API. The tag was resolved to the commit
recorded at the top. Current upstream documentation was checked separately;
it is not silently substituted for release behavior. A local LLVM 24 checkout
was useful for navigation only and was not treated as the pinned release.

### Reference cross-build and executed artifact

A focused upstream CMake probe built **unmodified LLVM 23.1.2 sources on macOS
AArch64 for Linux x86_64**, then ran the resulting static executable on a Linux
x86_64 remote executor. This establishes a useful reference artifact, not a
working Bazel LLVM-libc runtime/toolchain integration.

The downloaded compiler, redist source, and x86 UAPI archives were SHA256-checked
against this repository's indexes:

| Input | Version | SHA256 |
| --- | --- | --- |
| Darwin AArch64 compiler | `llvm-23.1.2-3` | `9175b0361a9838c9edac2fab86fd44fa566faee2a98c1efaa72b3c7c49f890a4` |
| LLVM source redist | `23.1.2-r1` | `271da53a2feb0cb221a9276a14268a3b76ad802c7fc8fb1098291a43b06e4c56` |
| Linux x86 UAPI | `7.0.10` | `0c55f71aa8614c4f5066d2d870c16c5c34228910878294e23f1ab4f64c120ba0` |

Python 3.11.14/PyYAML 6.0.3 ran upstream headergen in a scratch virtualenv. These
are reference-probe tools; hermetic Bazel exec-tool packaging remains future work.
For reproduction, `src` denotes the extracted LLVM source, `tools` the verified
compiler archive, `uapi_root` the directory containing `include/asm` and
`include/linux`, and `venv` the Python environment. Output directories below
are scratch paths, not repository files.

The successful libc-only configure/build was:

```sh
cmake -G Ninja -S "$src/runtimes" -B "$build" \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
  -DCMAKE_C_COMPILER="$tools/bin/clang" \
  -DCMAKE_CXX_COMPILER="$tools/bin/clang++" \
  -DCMAKE_C_COMPILER_TARGET=x86_64-unknown-linux-llvm \
  -DCMAKE_CXX_COMPILER_TARGET=x86_64-unknown-linux-llvm \
  -DCMAKE_AR="$tools/bin/llvm-ar" -DCMAKE_RANLIB="$tools/bin/llvm-ranlib" \
  -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_SYSROOT="$uapi_root" \
  -DLLVM_ENABLE_RUNTIMES=libc -DLLVM_LIBC_FULL_BUILD=ON \
  -DLLVM_INCLUDE_TESTS=OFF -DLIBC_TARGET_TRIPLE=x86_64-unknown-linux-llvm \
  -DLIBC_KERNEL_HEADERS=/include -DPython3_EXECUTABLE="$venv/bin/python"
ninja -C "$build" -j8 libc libm libc-startup
```

Observed results:

1. The first compile attempt with an absolute `LIBC_KERNEL_HEADERS` failed on
   `linux/errno.h`; inspection of the action established the doubled-sysroot path.
   With `/include`, all 1,752 build steps completed, producing generated headers,
   `libc.a` (about 5.1 MiB), `libm.a` (about 2.8 MiB), and crt1/crti/crtn objects.
2. `llvm-nm --defined-only` found expected public entrypoints including atexit,
   printf, write and dlopen, but no malloc/free. Linking a fixture with TLS,
   constructor, sin and atexit failed on malloc/free pulled by upstream atexit
   and new support. Removing explicit atexit and using section GC still did not
   eliminate the allocator requirement. This is direct evidence for including
   an allocator in the first runtime unit.
3. A separate compiler-rt builtins/CRT build succeeded after using generated
   LLVM-libc headers. UAPI alone had failed on `enable_execute_stack.c` needing
   `sys/mman.h`. It produced `libclang_rt.builtins-x86_64.a` and
   `clang_rt.crtbegin/end-x86_64.o`. The Bazel source set must be checked separately,
   but the reference build demonstrates a header-only bootstrap edge.
4. A second runtimes build enabled Scudo using the configuration below. The
   configure-time auxv probe initially could not see generated `sys/auxv.h` in
   the UAPI-only sysroot. After checking that generated header, the probe set
   `COMPILER_RT_HAS_AUXV=ON` explicitly. A future Bazel configuration must model
   the verified capability rather than reproduce host autodetection.
5. The original fixture then linked with LLVM-libc CRTs, compiler-rt
   crtbegin/builtins/crtend, libc and libm. The map identified Scudo malloc/free
   from `libc.a(wrappers_c.cpp.o)` and no other libc. `llvm-readelf -h -l -d -V`
   showed ELF64 x86-64 ET_EXEC, TLS, no PT_INTERP, DT_NEEDED or symbol versions.
6. A separate scratch Bazel 9.3.2 module ran the already-linked artifact with
   `build --config=remote --extra_execution_platforms=//:linux_x86_64
   --spawn_strategy=remote //:run_smoke` and an isolated output base. The
   [BuildBuddy invocation](https://app.buildbuddy.io/invocation/a764e90a-3d2b-4b5a-b986-57b786f5c551)
   recorded one remote action, exit zero and `LLVM libc static probe` from the
   atexit callback. The fixture checked constructor-initialized TLS and called
   sin on a volatile input before registering that callback.
7. An expanded lifecycle fixture also passed on the same remote execution
   platform: [invocation and logs](https://app.buildbuddy.io/invocation/1ea3227a-ad30-468d-87c1-538b169c5170).
   It checked malloc/realloc preservation/free, 64-byte aligned allocation,
   pthread create/join, independent initialized TLS and errno in the new thread,
   unchanged main-thread TLS/errno, and volatile unsigned 128-bit division.
   The link map confirmed extraction of compiler-rt's `udivti3.c.o`; the ELF
   remained static ET_EXEC with TLS and no interpreter/needed libraries.
   Exit zero plus `LLVM libc static lifecycle probe` from atexit established
   that these paths ran. This still does not cover signals, cancellation,
   arbitrary application APIs, kernel-version compatibility, or other CPUs.
8. The same lifecycle fixture passed with **driver-owned** startup/default-library
   insertion: [invocation and logs](https://app.buildbuddy.io/invocation/0eac9543-f554-414d-8b83-fa06eafa44be).
   A scratch sysroot staged LLVM libc crt1/crti/crtn, libc and libm under
   `usr/lib`, UAPI under `include`, and the resource tree staged the compiler's
   own headers plus canonical `clang_rt.crtbegin.o`, `libclang_rt.builtins.a`,
   and `clang_rt.crtend.o` under `lib/x86_64-unknown-linux-llvm`. A driver dry-run
   used those exact paths, with library-search directories only inside that
   layout. No GNU CRT aliases were needed. ELF/map inspection and remote
   execution repeated successfully. This supports reusing driver ownership
   while explicitly supplying its target artifacts and static-only policy.

The Scudo build used the same cross-compile configuration, replacing/adding:

```sh
-DLLVM_ENABLE_RUNTIMES='libc;compiler-rt'
-DLLVM_LIBC_INCLUDE_SCUDO=ON
-DRUNTIMES_USE_LIBC=llvm-libc
-DCOMPILER_RT_BUILD_GWP_ASAN=OFF
-DCOMPILER_RT_SCUDO_STANDALONE_BUILD_SHARED=OFF
-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON
-DCOMPILER_RT_BUILD_BUILTINS=OFF
-DCOMPILER_RT_BUILD_PROFILE=OFF
-DCOMPILER_RT_BUILD_XRAY=OFF
-DCOMPILER_RT_HAS_AUXV=ON
-DCOMPILER_RT_BUILD_SCUDO_STANDALONE_WITH_LLVM_LIBC=ON
-DCOMPILER_RT_SANITIZERS_TO_BUILD=scudo_standalone
```

Builtins used `compiler-rt/lib/builtins` as the CMake source, the same target,
compiler/assembler/archiver and sysroot, `COMPILER_RT_DEFAULT_TARGET_ONLY=ON`,
`COMPILER_RT_BUILD_CRT=ON`, and C flags
`-nostdlibinc -isystem <generated-libc-include> -idirafter=/include`.
The explicit final link used `-nostdlib -static -fno-pie -Wl,--gc-sections`,
the selected startup objects, and an archive rescan group for libc/libm/builtins.
The successful driver-owned variant used:

```sh
clang --target=x86_64-unknown-linux-llvm --sysroot="$layout/sysroot" \
  -resource-dir="$layout/resource" -nostdlibinc -isystem "$generated" \
  -idirafter=/include -fuse-ld=lld -static -fno-pie \
  --rtlib=compiler-rt --unwindlib=none lifecycle.c -lm
```

No full installation is claimed: an attempted libc component install stopped
on unbuilt `libmvec.a`. Source payload sufficient for this focused CMake build
does not prove every Bazel archive-extraction/overlay route.

Driver dry-runs separately established startup/default-library/loader behavior.
Linux x86_64/AArch64 triple handling and UEFI entrypoint differences above are
observed; no libc support is inferred from driver acceptance of ARMv7/s390x/
RISC-V spellings. Only the x86_64 reference fixtures were executed.

No existing libc behavior, public API, BUILD file, module dependency, compiler
prebuilt, or release workflow was changed. No claim of a Bazel-built LLVM-libc
runtime/toolchain, full C++ runtime, optional instrumentation sanitizer,
Windows execution, or standalone sysroot distribution qualification is made.
The broader test matrix remains the implementation acceptance plan, not a list
of tests already passed.

The largest remaining risks are faithful translation of the upstream entrypoint
graph, allocator/runtime cycles, per-architecture API differences, startup/TLS
semantics, and accidental C++/profile dependencies. These are reasons to make the
first unit small and observable; they do not justify silently weakening the
public contract or adding stubs until consumers link.

## Paste-ready change description

Investigate an experimental LLVM-libc option without implying support for every
existing target. Record the source, startup, allocator, ABI and toolchain
boundaries that a static Linux C integration must satisfy, plus the decisions
needed before implementation or a new public API. Keep C++, dynamic linking,
compiler-host migration and additional platforms behind separate evidence gates.
