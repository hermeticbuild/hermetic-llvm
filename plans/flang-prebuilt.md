# Flang prebuilt investigation and implementation plan

Investigation: 2026-11-15. Baseline: `02a44d57c9efc2410f70227fd61463a5f62cb6b1`.
Status: investigation only; no feature implementation or public API introduced.

## Recommendation and acceptance boundary

Publish a separate, versioned Flang distribution using the LLVM prebuilt release machinery. Do not put it in `prebuilt/extras`, enlarge the existing minimal LLVM archive, or add a Fortran ruleset dependency to the public module merely to publish binaries.

Start with **Linux x86_64 execution → Linux x86_64 musl, static executable**. This is the first required qualification pair, not a pair already demonstrated working. It matches the current Linux release policy and avoids assuming a host GCC installation, glibc version, or dynamic loader. Add macOS arm64 next, then expand the existing host matrix only after each pair passes.

Keep two distinct deliverables visible:

1. A relocatable compiler distribution: Flang, intrinsic modules, matching target Flang runtime, C interoperability headers, LLVM tools/linker, licenses and provenance. This is useful independently of Hermetic LLVM's C++ rule integration, but **does not alone make final linking hermetic**.
2. Fully hermetic native linking: add the target's CRT, libc, compiler builtins, sysroot and explicit driver defaults; demonstrate compile/link/run without host toolchain discovery. This is required before describing the distribution as a complete hermetic Fortran toolchain.

The simpler long-term Bazel integration is Flang compilation plus `cc_common.link` through the selected C++ toolchain. The existing ruleset does not implement that for Fortran-main executables. Avoid building a second general C++ toolchain adapter inside Hermetic LLVM just for this release. A self-contained Flang archive plus a narrowly scoped test adapter is a reasonable first implementation.

### Public API approval

The investigation adds no API. Proposed package name below is provisional. A new public `flang` extension, tag class, toolchain provider, source-selection switch, runtime label intended for downstream use, or `@llvm//...` adapter requires Corentin's explicit approval before implementation. Internal packaging rules and private test fixtures can reuse existing APIs. Do not infer approval for a new Bzlmod surface from approval to implement publishing.

## Current owning paths

| Concern | Owning implementation | Finding |
|---|---|---|
| Source selection | `MODULE.bazel`, `llvm_versions.json`, `extensions/llvm.bzl` | Current source version is 23.1.2; ordinary version selection already exists. |
| Source extraction | `private/llvm_project_archive.bzl:_default_excludes` | Explicitly excludes `flang` and `flang-rt`; still extracts their Bazel overlay. |
| LLVM package | `prebuilt/llvm/llvm_release.bzl` | Stage-3 multicall `llvm`, symlinks, Clang builtin headers, ASan/MSan ignorelists. No Fortran assets or complete sysroot. |
| Platform matrix | `prebuilt/platforms.bzl`, `prebuilt/llvm/BUILD.bazel` | Six default host platforms; separate Windows MSVC x86_64/aarch64 packages. |
| Publication | `.github/workflows/llvm-prebuilt.sh`, `.github/workflows/llvm-prebuilt.yml` | Branch/version check, remote release build, tar.zst, SHA256, attestation, immutable release assets. |
| Existing target runtime pieces | `runtimes/BUILD.bazel`, `runtimes/musl/BUILD.bazel`, `runtimes/compiler-rt/BUILD.bazel` | CRT object directory, resource directory, musl and builtins already exist. Reuse their actual outputs instead of sourcing host files. |

Source authority: [Hermetic LLVM baseline](https://github.com/hermeticbuild/hermetic-llvm/tree/02a44d57c9efc2410f70227fd61463a5f62cb6b1); [exact LLVM 23.1.2 source archive](https://github.com/hermeticbuild/llvm-redist/releases/download/llvmorg-23.1.2-r1/llvm-project-23.1.2.src.tar.zst), SHA256 `271da53a2feb0cb221a9276a14268a3b76ad802c7fc8fb1098291a43b06e4c56` (verified locally).

## Source/build gaps demonstrated

The source archive contains native Bazel targets `//flang/tools/flang-driver:flang` and `//flang-rt:runtime`. They are not ready to package unchanged:

1. Baseline compiler build fails during analysis because source extraction removed `flang/include/flang/Common/**/*.h`.
2. Restoring the omitted source trees in a scratch override makes compiler analysis pass. It does **not** establish compiler compilation or executable behavior.
3. Runtime analysis then fails: `//flang-rt:LibcSharedHeaders` cannot access `//libc:shared/rpc.h`, `rpc_dispatch.h`, `rpc_util.h` with this repository's libc overlay.
4. Diagnostic-only `--check_visibility=false` allows the macOS arm64 runtime archive to build. `nm -A -u` finds `__ZNSt3__122__libcpp_verbose_abortEPKcz` in I/O runtime objects. The upstream CMake build force-includes `flang-rt/lib/runtime/stl-overrides.h` expressly to avoid a dependency on the build compiler's C++ standard library; the Bazel overlay omits this.
5. The same runtime build targeting `//platforms:linux_amd64_musl` fails in `stop.cpp`: `execinfo.h` not found. The overlay hardcodes `HAVE_BACKTRACE=1`, `BACKTRACE_HEADER=<execinfo.h>`, `HAVE_STRERROR_R=1`, `HAVE_DECL_STRERROR_S=0`, explicitly describing these as typical Linux/glibc defaults.
6. There are no Bazel intrinsic-module generation targets in this source overlay. Building the driver alone cannot provide `iso_c_binding`, `iso_fortran_env`, IEEE modules or their internal prerequisites.

Fixes belong in source extraction and versioned source-overlay/runtime build configuration, not in archive renaming or a consumer wrapper. Do not use disabled visibility checking as a production fix. Compare the actual source lists with `flang-rt/lib/runtime/CMakeLists.txt`; its supported/host/GPU/float128 split is more precise than the overlay's broad `.cpp` glob.

The runtime also inherits `//llvm:Support` through public header dependencies in the existing overlay. Inspect the resulting link closure rather than assuming the archive contains all transitive code, or assuming all compiler-side dependencies are required at runtime.

## Archive contents and layout

Proposed artifact: `flang-toolchain-<llvm-version>-<host-suffix>.tar.zst`, separate from the unchanged `llvm-toolchain-minimal-*` assets. Publish with the same SHA256/attestation/immutable-asset discipline. A dedicated `flang-*` workflow/branch namespace avoids making ordinary LLVM bootstrap releases depend on the much larger Flang/MLIR graph; the final naming and trigger policy need confirmation before becoming a published contract.

The first complete Linux x86_64-musl archive needs the following closure:

| Path/content | Required behavior |
|---|---|
| `bin/flang` | Native Linux x86_64 executable, statically linked against musl and required C++ support; integrated `-fc1` frontend. |
| `bin/llvm`, `bin/ld.lld`, `bin/llvm-ar`, optional conventional aliases | Same-version existing LLVM tools; linker selection must resolve inside the extracted archive. `flang-new` compatibility alias only if intentionally supported. |
| `lib/clang/23/finclude/flang/<normalized-target-triple>/*.mod` | Modules built by the matching 23.1.2 compiler for the target, not copied from another version or execution architecture. |
| `lib/clang/23/lib/<normalized-target-triple>/libflang_rt.runtime.a` | Target archive, CMake-equivalent host runtime selection, correct libc configuration, no accidental build-host C++ ABI dependency. |
| Matching compiler-rt builtins in the resource directory | Exact naming required by driver tracing; do not add libgcc fallback. |
| `include/ISO_Fortran_binding.h` | Matching C descriptor ABI header and any directly required packaged headers. |
| `sysroot/usr/include/**` | Target musl and required kernel header closure for C interop/preprocessing; no developer-machine includes. |
| `sysroot/usr/lib/{crt1.o,Scrt1.o,rcrt1.o,crti.o,crtn.o,libc.a,...}` | Reuse target CRT/musl outputs; package actual math/pthread/etc. compatibility archives if the driver requests them. Determine the exact set from the final driver command and archive inspection. |
| Driver defaults/configuration | Relocatable target, resource directory, sysroot, linker, compiler-rt, static-link policy. Prevent host GCC/startfile fallback. Test the chosen mechanism; do not assume a config file is automatically discovered. |
| License/provenance files | LLVM and bundled runtime source versions, hashes, licenses; keep host and target identities explicit. |

This is a required closure specification, not a claim that the current targets already produce this installed layout. Derive the exact normalized triple and final paths from `flang -###`, `-print-resource-dir`, selected target and real output files. Static non-PIE is the simplest initial link contract; add PIE/shared modes only with their own CRT and runtime tests.

### Intrinsic modules

In 23.1.2, `clang/lib/Driver/ToolChain.cpp:getDefaultIntrinsicModuleDir` searches `ResourceDir/finclude/flang/<target-subdir>`. `clang/lib/Driver/ToolChains/Flang.cpp` explicitly notes platform-dependent preprocessing of modules. The older third-party 21.1.8 package used in this investigation installs `include/flang/*.mod`; copying that layout for 23 is incorrect.

Use `flang-rt/lib/runtime/CMakeLists.txt:module_sources` as the inventory: `__fortran_builtins`, `__fortran_ieee_exceptions`, `__fortran_type_info`, `flang_debug`, `iso_fortran_env`, `iso_fortran_env_impl`, `ieee_arithmetic`, `ieee_exceptions`, `ieee_features`, `iso_c_binding`, plus upstream CUDA-related modules if claiming complete CPU-package parity. PPC modules are target-conditional. CUDA-related modules do not imply shipping or supporting CUDA execution. Generate in dependency order with a Flang executable in the **execution configuration** and the intended target flags; declare all module outputs/inputs. Do not run the target-platform driver during cross compilation. Keep module files and any runtime implementation objects distinct; CMake says the current module-build object files are unused.

### Platform boundaries

- Linux x86_64 musl first; Linux aarch64 musl next after equivalent tests. A musl-host compiler can emit glibc targets, but that requires a separate glibc target runtime/sysroot qualification.
- macOS needs the packaged/declared SDK and Darwin linker/builtins conventions; `lib/clang/<major>/lib/darwin` differs from non-Darwin runtime placement. Native execution still depends on OS libraries; no Homebrew/Xcode compiler dependency is acceptable.
- Windows GNU and Windows MSVC are different target contracts. Driver executable ABI, target ABI, CRT and final linker must be recorded independently. Do not infer one from the compiler's host filename.
- MSVC Flang emits dependent runtime-library directives. The upstream driver recognizes `flang_rt.runtime.static.lib`, `.static_dbg.lib`, `.dynamic.lib`, `.dynamic_dbg.lib`; the latter are static Fortran archives using dynamic CRT, not Fortran DLLs. Match CRT selection and distribute/declare SDK/MSVC inputs under existing repository constraints. Existing runtime Bazel configuration is not Windows-ready.
- OpenMP, accelerator offload, real(16)/quadmath, shared runtime and cross-target support require explicit qualification. A release must list unsupported modes instead of silently using host installations.

## Existing ruleset assessment

[miinso/rules_fortran](https://github.com/miinso/rules_fortran/tree/f0cac73ebdcbda7bc01b38b8a4ee33869416c220), inspected revision `f0cac73ebdcbda7bc01b38b8a4ee33869416c220`. Latest release observed: v0.1.0 (2026-03-06); repository pushed 2026-08-24, 5 stars. Small project: useful starting point, limited adoption evidence. Its default toolchain downloads [Flang 21.1.8](https://github.com/miinso/flang-releases/releases/tag/v21.1.8), not this repository's LLVM 23.1.2.

Demonstrated: native macOS arm64 Fortran hello and C-main calling a `bind(c)` Fortran library pass. The C example prints the expected `25.0`, but its upstream test neglects to return its error counter; do not reuse it unchanged as a regression test.

Integration findings:

- `fortran_library` supplies `CcInfo`, including runtime libraries. This supports C/C++-owned final linking and is the promising integration route.
- `fortran_binary` and `fortran_test` perform their own `ctx.actions.run` through `toolchain.linker`; they do not call `cc_common.link`. Registering Hermetic LLVM's C++ toolchain cannot supply its startup objects, sysroot, link features or runtime selection to these actions automatically.
- Stock macOS linker flags hardcode `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk`. The action uses the default shell environment. `flang -###` selects `/usr/bin/ld`.
- Reproduced repository bug: on a macOS arm64 host, `@flang_linux_x86_64//:flang-new` contains a **Mach-O arm64** executable. `_flang_repository_impl` uses `repository_ctx.os`; the platform loop never passes the requested platform. Stock cross-host remote execution cannot be trusted.
- Stock toolchains pair identical execution/target OS and CPU. No Windows arm64 toolchain; no musl/glibc constraint distinction.
- Download rule assumes `flang+llvm-<version>` strip prefix and old file naming. Use an explicit `http_archive` plus an existing `fortran_toolchain` declaration in the test module for the new artifact; do not distort the release layout to satisfy this downloader.
- `fortran_toolchain.all_files` includes compiler/linker/archiver and `tool_deps`, but not `runtime_libraries` automatically. The fixture must put the entire declared tool/runtime/sysroot closure in `tool_deps` as well as the target runtime link list.

Recommended first adapter: a test-local `fortran_toolchain` using the extracted complete archive's compiler/linker/archiver, target-specific compiler flags and matching runtime. For a C-main fixture, register the existing Hermetic LLVM C++ toolchain and verify `CppLink` actually owns final linking. For Fortran-main fixtures, retain the packaged Flang driver until an upstream `cc_common.link` integration is designed; this avoids pretending that replacing its `linker` attribute with an arbitrary linker binary supplies C++ toolchain features.

## Test evidence and reproduction

Scratch files are investigation artifacts, not product changes. Full logs remain under `/tmp`; key results and commands are retained here. Every Hermetic LLVM Bazel invocation used `--config=remote` and isolated output bases. The standalone ruleset fixture has no `remote` config and was intentionally native.

### Baseline

From this worktree:

```sh
bazel --output_base=/tmp/flang-investigation-output query --config=remote \
  '@llvm-project//flang/... + @llvm-project//flang-rt/...'
bazel --output_base=/tmp/flang-investigation-output build --config=remote \
  '@llvm-project//flang/tools/flang-driver:flang'
```

Both fail empty-source globs. [Compiler baseline build](https://app.buildbuddy.io/invocation/22f8ebf6-b130-443d-8807-e6e40a91a890). Logs: `/tmp/flang-query.log`, `/tmp/flang-build-baseline.log`.

### Restored-source diagnostic override

Verified the source archive hash above. Extracted only `flang` and `flang-rt` to `/tmp/flang-source-23.1.2`. Created `/tmp/flang-complete-source` with these source trees overlaid by the original fetched BUILD files; other root entries symlink to the original fetched repository. Used a second output base so that original repository remains intact. This experiment changes no repository source/build files.

```sh
bazel --output_base=/tmp/flang-complete-output build --config=remote \
  --override_repository=+llvm+llvm-project=/tmp/flang-complete-source \
  '@llvm-project//flang/tools/flang-driver:flang' '@llvm-project//flang-rt:runtime'
```

Fails libc shared-header visibility. [Build](https://app.buildbuddy.io/invocation/d9f6f32d-585d-4ace-abd2-f3fa011f1013). Log: `/tmp/flang-build-restored-sources.log`.

```sh
bazel --output_base=/tmp/flang-complete-output build --config=remote \
  --check_visibility=false \
  --override_repository=+llvm+llvm-project=/tmp/flang-complete-source \
  '@llvm-project//flang-rt:runtime'
nm -A -u /tmp/flang-complete-output/execroot/_main/bazel-out/darwin_arm64-fastbuild/bin/external/+llvm+llvm-project/flang-rt/lib/runtime/libflang_rt.runtime.a
```

Build succeeds: 956 total actions, 599 remote processes, 37.932 seconds. Archive inspection finds libc++ verbose-abort references in `descriptor-io.pic.o`, `edit-output.pic.o`, `io-api.pic.o`, etc. [Build](https://app.buildbuddy.io/invocation/bfcf680a-d398-42d5-9276-e2f366bd3370). Log: `/tmp/flang-runtime-probe.log`; undefined-symbol output: `/tmp/flang-runtime-undefined.txt`.

Repeat with `--platforms=//platforms:linux_amd64_musl`: fails `stop.cpp:21:10: fatal error: 'execinfo.h' file not found`; generated config expands `BACKTRACE_HEADER` to `<execinfo.h>`. [Build](https://app.buildbuddy.io/invocation/a8ad5de3-9f14-476f-99b7-914db34cd990). Log: `/tmp/flang-runtime-musl.log`.

Compiler-only restored-source `build ... '@llvm-project//flang/tools/flang-driver:flang' --nobuild` passes analysis, 35,702 configured targets, zero actions executed. [Analysis](https://app.buildbuddy.io/invocation/9749fe9f-9f4d-4aaa-a4e0-16e810532a7d). Log: `/tmp/flang-driver-analysis.log`. Full driver compilation and all LLVM 23 Fortran execution remain unproven.

### Third-party ruleset fixture

Clone inspected revision under `/Users/corentinkerisit/code/github.com/miinso/rules_fortran.git`. Fixture `/tmp/flang-ruleset-probe` uses that checkout via `local_path_override`, `rules_cc` 0.2.17, and copies upstream `examples/basic/hello.f90`, `examples/interop/{fortran_math.f90,c_calls_fortran.c}`. BUILD declares `fortran_test(hello)`, `fortran_library(fortran_math)` and `cc_test(c_calls_fortran)`.

```sh
USE_BAZEL_VERSION=9.3.2 bazel --output_base=/tmp/flang-ruleset-output \
  test //:hello //:c_calls_fortran --test_output=all
USE_BAZEL_VERSION=9.3.2 bazel --output_base=/tmp/flang-ruleset-output \
  aquery 'mnemonic("Fortran.*|CppLink", //:hello + //:c_calls_fortran)' --output=text
/tmp/flang-ruleset-output/external/rules_fortran++flang+flang_macos_aarch64/bin/flang-new \
  -### hello.f90 -o /tmp/flang-probe.out
```

Two tests pass; output includes `Hello from Fortran with rules_fortran!` and `PASS: fortran_square(5.0) = 25.0`. [Run](https://app.buildbuddy.io/invocation/f2a18b72-5ec3-4dda-a634-2c6e482475b6). The action graph confirms `FortranLinkTest` invokes Flang with the system SDK flag, while `CppLink` uses the local C++ toolchain. Driver tracing selects `/usr/bin/ld`; `otool -L` shows Flang depends on `/usr/lib/libSystem.B.dylib` and `/usr/lib/libc++.1.dylib`. These tests do not establish Hermetic LLVM integration.

Adding `use_repo(flang, "flang_linux_x86_64")`, then querying `@flang_linux_x86_64//:flang-new` and running `file` on its `bin/flang` reports `Mach-O 64-bit executable arm64`. [Query](https://app.buildbuddy.io/invocation/d12bc545-96e1-4e70-8000-9c2df0de03bd). Logs: `/tmp/flang-ruleset.log`, `/tmp/flang-ruleset-actions.txt`, `/tmp/flang-wrong-platform.log`.

## Actionable implementation sequence

1. **Restore/build source support.** Remove Flang source exclusions or otherwise use the existing source repository inputs without a new public switch. Repair libc shared-header ownership narrowly. Build the compiler and target runtime independently. Port CMake runtime feature definitions, explicit source selection and forced STL override header. Use target constraints for backtrace/strerror configuration; preserve musl and Windows distinctions. Keep runtime archives machine code unless LTO distribution is explicitly designed; the release config currently enables thin LTO globally.
2. **Generate intrinsic modules.** Private build rule/action; same-version execution-platform Flang, target flags, ordered dependencies, declared outputs. Match the selected compiler's search layout. Cover ISO C/Fortran environment and IEEE modules before archive work.
3. **Package compiler/runtime closure.** Separate internal `prebuilt/flang` package modeled on mtree/tar LLVM packaging. Ensure compiler runtime dependencies, target archive, C header, modules, licenses and LLVM tools are present. No `extras` edits. Inspect tar paths, permissions and symlink targets.
4. **Complete native Linux static linking.** Assemble declared musl sysroot, CRT and compiler builtins from existing targets. Configure relocatable Flang defaults and bundled LLD. Verify `-###` uses archive paths only. Avoid silently falling back to GCC/libgcc. Check `readelf -l/-d` on compiler and generated executable: no ELF interpreter or NEEDED entries for the promised static pair.
5. **Add focused archive tests.** Unpack to a directory containing spaces, move it again, compile and run under an empty/controlled environment on a minimal Linux worker. The test's action inputs must include only archive + sources + declared runner. Add a negative test proving a missing module/runtime/linker fails rather than finding a host fallback.
6. **Exercise the ruleset.** Test-local dependency and toolchain declaration using this artifact. Fortran-main test through packaged Flang; C-main `bind(c)` test through Hermetic LLVM `cc_common.link`/`cc_test`. Inspect both action graphs. Fix/assert return statuses; do not rely on upstream examples' exit codes alone. Qualify remote execution from macOS without the stock downloader's wrong-host bug.
7. **Wire release publication.** Dedicated version/branch contract, same build flags/security environment/checksums/attestations/non-overwrite behavior as LLVM. Release workflow must run archive consumption tests before publishing. Add platform lanes only after real compile/link/run plus artifact inspection. Document exact supported host/target/CRT combinations.

## Required acceptance scenarios

- Relocated archive: `--version`, resource lookup, trivial compile, native link and execution with empty PATH; no undeclared host compiler/linker/SDK/GCC paths in trace.
- Runtime: formatted I/O, allocation/arrays, math, `stop` failure status; object/archive inspection for C++ ABI dependencies and executable dependency inspection.
- Modules: `iso_c_binding`, `iso_fortran_env`, IEEE arithmetic; a user module consumed by a second compilation; preprocessing and include inputs; matching target-kind values.
- Interop: C calls `bind(c)` Fortran and Fortran calls C; descriptor API via `ISO_Fortran_binding.h`; correct final-link owner and target runtime.
- Boundaries: unsupported target/ABI/mode clearly rejected or documented; missing packaged runtime/module cannot be satisfied by host paths; ordinary minimal LLVM tarball remains unchanged.
- Build portability: source archive mode and release configuration; Linux x86_64-musl first; each additional host/target independently qualified. No Windows, OpenMP, CUDA, quadmath or shared-link success is implied by native hello-world.

## Suggested short PR description after implementation

> Publish a separate Flang toolchain so Fortran users can compile and link without installing a host Fortran toolchain. Keep the minimal LLVM distribution unchanged and package the matching intrinsic modules and target runtime together, with explicitly qualified linker/CRT/sysroot inputs for the supported targets.

Replace the last clause with the actually demonstrated scope before opening a PR. If final linking still uses host SDK/CRT tools, say so and do not call the result fully hermetic.
