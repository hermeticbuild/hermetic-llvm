# Flang prebuilt investigation and implementation plan

Investigation: 2026-11-15. Baseline: `02a44d57c9efc2410f70227fd61463a5f62cb6b1`.
Status: investigation only; no feature implementation or public API introduced. Updated after Corentin's design correction: **minimal host Flang prebuilt; target modules, runtime and sysroot supplied by Hermetic LLVM**. The earlier self-contained target distribution is superseded, not the desired release contract.

## Recommendation and acceptance boundary

Publish a separate minimal, versioned **host compiler** distribution using the LLVM prebuilt release machinery. Its core is `bin/flang` plus the host-side dependencies actually required to execute it, licenses and provenance. Do not put it in `prebuilt/extras`, enlarge the existing minimal LLVM archive, bundle a target sysroot, or add a Fortran ruleset dependency to the public module merely to publish binaries.

Start host qualification with **Linux x86_64-musl Flang**, matching the existing Linux LLVM executable policy. Distinguish the compiler's execution platform from its output target. Separately qualify a Linux x86_64-musl Fortran target with Hermetic LLVM's target-side inputs; the host archive must not fix that target or static-link policy in an installed `flang.cfg`.

Keep these ownership boundaries:

1. Host prebuilt: Flang driver, integrated frontend/code generator and required host executable dependencies. Ordinary CPU `-c` needs no separately packaged Clang, assembler, LLVM optimization tools or linker.
2. Hermetic LLVM target configuration: target intrinsic modules, Flang runtime, ISO C binding header, compiler builtins, libc/CRT/sysroot/SDK and selected linker. Generate modules with the matching **execution-platform** Flang and target flags; compile the runtime with the **target-platform** C++ toolchain.
3. Consumer rule or explicit outside-Bazel environment: compose those declared inputs. Prefer separate Flang compile actions followed by `cc_common.link`; language-appropriate target runtimes are explicit link dependencies. An outside-Bazel cross environment, if later implemented, is a separate composition product, not content added to the host compiler tarball.

Source inspection supports Clang-owned final links for both Fortran-main and C-main programs in LLVM 23.1.2. A subsequent focused probe demonstrated the Fortran-main path with `cc_common.link`, as recorded below; this does not prove a complete consumer adapter. The stock ruleset lacks that path for Fortran-main executables. Do not replace this missing integration by silently changing the release into a bundled target distribution.

### Public API approval

The investigation adds no API and does not change the separately approved artifact/tag naming. A new public `flang` extension, tag class, toolchain provider, source-selection switch, runtime label intended for downstream use, or `@llvm//...` adapter requires Corentin's explicit approval before implementation. Internal packaging rules and private test fixtures can reuse existing APIs. Do not infer approval for a new Bzlmod surface from approval to implement publishing.

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

## Minimal host archive and driver audit

The source references below are to the exact 23.1.2 archive identified above; Clang driver files were inspected in its fetched repository, Flang/Flang-RT files in the extracted archive. They are not claims about older Flang releases.

| Operation | Executables and inputs required | Owning source |
|---|---|---|
| Ordinary CPU `flang -c input.f90 -o input.o` | Flang invokes itself with `-fc1 ... -emit-obj`. Native code generation and object emission are integrated. No external `clang`, `as`, `opt`, `llc` or linker is required for this path. | `clang/lib/Driver/ToolChains/Flang.cpp:1037–1076,1344–1358`; `Flang.h:155–157`; `flang/tools/flang-driver/driver.cpp:62–72,125–135`. |
| Fortran preprocessing | Integrated CPP, source/include inputs and selected preprocessor definitions; no external C preprocessor for the ordinary path. | `Flang.h:156`; `Flang.cpp:1055–1059`. |
| Source using intrinsic modules | Matching target `.mod` inputs, selected via `-fintrinsic-modules-path` or the target-specific resource directory; these are compile-time data, not host compiler dependencies. User `.mod` and textual includes must also be declared. | `ToolChain.cpp:1175–1178`; `Flang.cpp:1203–1235`. |
| Target runtime archives during `-c` | Not opened/linked by ordinary compilation. Runtime calls and, for MSVC, dependent-library directives can be emitted without those archives being present. Host libraries needed to execute a dynamically linked Flang are a different dependency. | `Flang.cpp:1037–1076,485–532`. |
| Plain `flang input.o ... -o app` | The platform-specific external linker plus target startup objects, Fortran runtime, compiler runtime, libc/math libraries and platform SDK/system libraries. Flang constructs the link command; it does not invoke a Clang driver as its normal linker. | `Gnu.cpp:450–540`; `Darwin.cpp:749–758`; `MinGW.cpp:263–273`; `MSVC.cpp:191–200`. |
| `clang --driver-mode=flang ...` | The Clang driver explicitly searches for a separate `flang` executable for frontend jobs. This is an alternative composition, not evidence that `bin/flang` needs `bin/clang`. | `Flang.cpp:1344–1358`. |

The host archive therefore does not need target `.mod`, Flang-RT, compiler-rt builtins, libc headers/libraries, a target `flang.cfg`, LLD or the LLVM multicall binary solely to support normal Fortran compilation. Linux static executable closure was inspected in the preceding implementation review; other host executable dependencies must be inspected independently (`readelf`, `otool`, PE imports). This audit has not rebuilt or executed a newly stripped-down host-only archive.

The audit covers ordinary CPU compilation and linking. Offload, CUDA, OpenMP target devices, optional math libraries, compiler plugins and other opt-in modes may require additional tools/data; no blanket claim is made that every possible Flang invocation requires only one executable. Backend coverage also depends on how the host compiler was built.

### Final-link ownership and ordering

**Fortran main is generated during compilation.** `flang/lib/Lower/Bridge.cpp:616–626` calls `fir::runtime::genMain` when a main program is present. `flang/lib/Optimizer/Builder/Runtime/Main.cpp:22–81` emits a normal externally visible C `main`, calling `_FortranAProgramStart`, `_QQmain`, and `_FortranAProgramEndStatement`. The source regression `flang/test/Driver/emit-mlir.f90:15–26` checks that wrapper. Thus LLVM 23.1.2 does not require a separately linked `FortranMain` archive to turn `_QQmain` into the process entry point. The comment in `clang/lib/Driver/ToolChains/MSVC.cpp:198–199` still says the runtime defines `main`; the lowering implementation and regression are more authoritative than that stale comment.

**A normal Clang/Clang++ final link is viable in principle.** Compile Fortran to target objects first, then supply them, other native dependencies and the matching Flang runtime to the Hermetic LLVM C++ link action. The native startup objects call the emitted `main` normally. Clang does not automatically infer a Flang runtime dependency merely from a `.o`; the runtime must be represented explicitly. A consumer using `cc_common.link` should create compilation outputs from the Fortran objects and use target-side `CcInfo` linking contexts for runtime and native libraries. Preserve the selected C++ toolchain's target, sysroot, CRT, linker, runtime mode and inputs. Its action may use `clang++` and add C++ runtime libraries; do not claim that choosing `cc_common.link` necessarily produces a C-only link.

For the GNU/Linux driver, `Gnu.cpp:475–485` deliberately places the Fortran runtime **after program/linker inputs, before `-lm` and the compiler/C runtime group**. `ToolChain.cpp:972–1053` adds these language dependencies:

- Ordinary CPU: `libflang_rt.runtime` (an explicit archive path with `-static-libflangrt`, otherwise `-lflang_rt.runtime`). Linux additionally appends `-lm`; libc and compiler builtins/libgcc come from the ordinary platform driver.
- Configured real(16) math support: `-lflang_rt.quadmath`, configured F128 math provider with the driver's as-needed policy, then the main runtime. This is conditional, not a default package requirement established by this audit.
- BSD runtime backtrace paths: `-lexecinfo` where the driver selects it.
- OpenMP: the platform driver adds the OpenMP runtime; Flang's helper can additionally require libatomic when using libomp plus libgcc (AIX differs).
- Windows MSVC: `Flang.cpp:485–532` emits dependent-library directives for compiler builtins, CRT and the corresponding `flang_rt.runtime.{static,static_dbg,dynamic,dynamic_dbg}.lib`; default is static CRT. A Clang/clang-cl/LLD-owned final link must honor or deliberately replace these directives consistently, and provide the actual target inputs. The Fortran driver also adds `/subsystem:console`.

Model the runtime as a real target dependency, not an absolute `-L` string. Check the final action order because traditional static linkers resolve archives according to preceding unresolved symbols; success under LLD alone can hide an ordering problem. Compiler runtime and libc supply dependencies introduced by Flang-RT, so moving the latter after those libraries is not a faithful port of the driver contract. The source runtime is C++ implementation code, but `flang-rt/cmake/modules/AddFlangRT.cmake:263–283` force-includes `stl-overrides.h` to avoid a build-host C++ library dependency. Preserve that behavior when producing target `CcInfo`.

**Do not set Flang's raw linker path to `clang` and assume integration is done.** `ToolChain.cpp:1261–1323` selects a linker via `--ld-path`, `-fuse-ld`, program paths and platform defaults; the toolchain then sends that executable raw linker arguments. Supplying a real Hermetic LLVM LLD is possible but still leaves Flang responsible for assembling all target paths/defaults. A separate Clang final-link action is the clean ownership boundary. An adapter translating raw linker arguments would be a different, unimplemented design.

For C-main callers, `flang-rt/lib/runtime/main.cpp:36–43` notes that I/O initializes on demand, which supports non-Fortran `main`. This does not establish all command-argument/environment or initialization semantics for arbitrary mixed-language applications; qualify those when needed.

### Comparison with rules_rust and cross environments

Inspected clean `hermeticbuild/rules_rust` revision [`b554c95ddb5b69bd8505745b47a3a0898d2a096c`](https://github.com/hermeticbuild/rules_rust/tree/b554c95ddb5b69bd8505745b47a3a0898d2a096c), `rust/private/rustc.bzl`:

- Default rustc-owned linking obtains the selected C++ tool and link variables (`_get_linker_config`, lines 421–458), environment and expanded link arguments, then passes `--codegen=linker=...` and individual `--codegen=link-arg=...` arguments to rustc (lines 1543–1600). Linker files are declared inputs (lines 880–887,949–958). The executable name alone is not the integration.
- Its separate `cc_common.link` path emits a Rust object, creates `compilation_outputs`, collects std/allocator/runtime/native `CcInfo` contexts, and invokes the C++ link action (lines 2075–2098,2436–2475,2526–2540). This is the closer pattern for Flang: host compiler → target object; explicit language runtime → target link graph; selected C++ toolchain → final link. Rust-specific allocator, panic, stdlib and LTO logic should not be copied into Fortran rules.
- Rust can pass C++-driver arguments to a selected driver because rustc owns a supported driver interface. Flang's `--ld-path` selects the raw linker's interface. These mechanisms are not interchangeable merely because both options choose an executable.

At the inspected Hermetic LLVM baseline, README's crossenv section calls the interface WIP and lists minimal LLVM host archive targets; no completed general crossenv exporter was found in the tracked implementation. Do not describe a hypothetical Fortran crossenv wrapper as an existing reusable facility. The useful architectural pattern is to compose host tools with explicitly selected target sysroot/runtime inputs outside the host tarball. The final external API/layout remains to be proposed, approved and tested.

### Focused composition evidence after the source audit

The coordinating agent created `/tmp/flang-cc-common-probe`; this investigator inspected its `probe.bzl`, BUILD/MODULE files, four test logs and the source-runtime link action dump. Four Linux x86_64-musl remote test scenarios pass, including the final minimal-directory rerun:

- [Fortran main through `cc_common.link`](https://app.buildbuddy.io/invocation/88177cdc-9b5d-4e0a-929d-424daa104250): compile action declares only Flang and `main.f90`, with `--no-default-config -target x86_64-unknown-linux-musl -c`. Its output is linked by Hermetic LLVM's selected C++ toolchain with a separately declared `libflang_rt.runtime.a` linking context. Test output: `Flang cc_common link probe`.
- [External intrinsic-module inputs](https://app.buildbuddy.io/invocation/fb079636-81df-43e9-9386-52d6bb8450af): same action additionally declares ten `.mod` files and uses `-fintrinsic-modules-path`; source imports `iso_fortran_env`, `iso_c_binding`, `ieee_arithmetic`. Test output: `7`.
- [Source-built target runtime](https://app.buildbuddy.io/invocation/ca66ffd7-8473-44f9-8792-f2da2f763f2c): `//:source_runtime_test` replaces the packaged runtime with `@llvm-project//flang-rt:runtime` and consumes its complete `CcInfo.linking_context`, including transitive dependencies. The Flang compile action still uses only the executable, source and ten external `.mod` files. Hermetic LLVM's `cc_common.link`/Clang++ owns final linking with the source-built runtime and selected musl/CRT/builtins/LLD closure. Test output: `7`; coordinating-agent report: 33.8 seconds, 344 remote actions. This demonstrates the desired link-owner/runtime-owner split for this pair.
- [Source-generated target modules](https://app.buildbuddy.io/invocation/81db9ec3-bf31-483e-a6d1-17f77eeb9692): `//:source_modules_test` adds a declared `ProbeFlangModules` action using only the prebuilt Flang executable as a host tool. It consumes ten LLVM 23.1.2 intrinsic-module `.f90` sources and `flang/Runtime/magic-numbers.h`, runs `-target x86_64-unknown-linux-musl -fsyntax-only -module-dir <output-directory> -I <output-directory>`, and declares ten `.mod` outputs. A separate compile action consumes those outputs with `-fintrinsic-modules-path`, then C++-owned linking consumes the source-built runtime. Test output: `7`.
- [Minimal host-directory rerun](https://app.buildbuddy.io/invocation/67f223cd-6391-486d-bfaa-ef802dcc2208): the same `//:source_modules_test` passes after repointing `@flang_prebuilt` to `/tmp/flang-minimal-dist`, containing only `bin/flang`, two license files and Bazel BUILD/MODULE metadata. No modules, runtime, sysroot, `flang.cfg` or LLVM tools are present. Both module generation and compilation now use ordinary default-config lookup, without `--no-default-config`. The coordinating agent reports three remote actions reran; inspected test output: `7`. This demonstrates the host-file closure and full component separation in this scratch fixture for Linux x86_64-musl.

The inspected `/tmp/flang-source-runtime-actions.txt` provides stronger link evidence than the exit code: `CppLink` executes Hermetic LLVM's `clang++ -target x86_64-linux-musl --sysroot=/dev/null -static -fuse-ld=lld`, with declared `-B` CRT, `-L` musl and `-resource-dir` paths. The Fortran object precedes `-Wl,--start-lib` and source-built `flang-rt/.../*.pic.o` inputs. The runtime linking context expands to objects, not the earlier packaged archive; Flang is not the final-link driver.

The fixture configures `fully_static_link`, uses `cc_common.create_library_to_link` / `create_linker_input` / `create_linking_context`, and supplies the compiled object in both `objects` and `pic_objects`. The coordinating agent reported an initial undefined-`main` link when only `objects` was supplied; the final inspected fixture matches rules_rust's object-selection pattern. For production, compilation flags must actually satisfy the PIC model when advertising PIC output; listing an arbitrary non-PIC object twice is not a general PIC solution.

**Limit:** The first three scenarios use the earlier bundled distribution at `/tmp/flang-prebuilt-e2e.0Py3GM/distribution` for Flang and intrinsic modules; the first two also use its runtime archive. The final scenario generates modules from sources copied from the exact LLVM source archive, preserving their relative include paths. All compiler binaries still originate from the earlier build; the minimal directory is hand-assembled, not a newly produced release tarball. Source runtime builds depend on overlay fixes currently on the old draft implementation branch. Full component separation is demonstrated for this host/target pair, but production module generation/selection, release packaging, other platforms and a general ruleset remain unproven. The investigator did not rerun these builds; source, file closure, link action and result artifacts were inspected, and invocation links were supplied by the coordinating agent. The scratch fixture's old targets refer to files removed from the minimal repository; only `//:source_modules_test` is qualified in its final state.

### What is still unproven

- A new minimal host-only archive compiling in isolation, with all intrinsic modules supplied outside it; all additional host OS/architecture pairs.
- Production integration of the demonstrated source-module generation action, including target selection and source/header dependency ownership; preservation of the demonstrated source-runtime overlay repairs in the corrected implementation.
- General Fortran/runtime coverage and portable final library order beyond the focused Linux x86_64-musl composition probe; in particular other linkers and platform-specific runtime dependencies.
- Cross-target intrinsic modules and runtime ABI agreement, especially MSVC default-library/CRT handling; dynamic links and optional runtimes.
- A generic consumer adapter/provider contract or outside-Bazel crossenv interface. No ruleset or such API was written in this audit.

## Historical target archive proposal (superseded)

The following records the initial bundled-distribution proposal and is **not** the current implementation plan. Corentin subsequently required target-side assets to remain in Hermetic LLVM. Keep it only as context for the earlier experiments below.

Proposed artifact: `flang-toolchain-<llvm-version>-<host-suffix>.tar.zst`, separate from the unchanged `llvm-toolchain-minimal-*` assets. Publish with the same SHA256/attestation/immutable-asset discipline. A dedicated `flang-*` workflow/branch namespace avoids making ordinary LLVM bootstrap releases depend on the much larger Flang/MLIR graph; the final naming and trigger policy need confirmation before becoming a published contract.

The earlier complete Linux x86_64-musl archive proposal contained the following closure:

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

This historical table must not be used to enlarge the minimal host tarball. The target-side requirements still matter when composing a complete compile/link environment, but they belong to separately configured Hermetic LLVM targets.

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

For the corrected design, this ruleset remains evidence of a consumer, not an implementation requirement. Its compile actions could consume a minimal host Flang plus declared target modules. Its existing Fortran-main link rule still needs an actual C++ toolchain integration; pointing its linker at a minimal Flang does not provide target runtime/sysroot inputs, and pointing it at raw Clang does not provide C++ toolchain flags. The prior complete-archive adapter tested a different architecture and must not be treated as proof of the corrected path.

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

1. **Retain source-build repairs that belong to each component.** Compiler extraction/build support is independent of the target runtime. Keep target libc configuration, STL overrides and native archive policy with the runtime, not the host package. Do not introduce a new public API implicitly.
2. **Reduce the archive to host executable closure.** Separate `prebuilt/flang` artifact, no target-fixed config, intrinsic modules, runtime, sysroot or duplicated LLVM tool bundle. Inspect host imports/dynamic dependencies, archive paths and provenance. Host-static Linux remains a packaging property, not the Fortran target's link policy.
3. **Model target modules/runtime in Hermetic LLVM.** Matching execution compiler generates target modules; selected target C++ toolchain builds Flang-RT. Keep `.mod` dependencies, the ISO C binding header and runtime linking context explicit. Propose any new downstream-facing labels/provider/extension API before implementing it.
4. **Promote the proven C++-owned composition into a focused regression.** The minimal-directory probe passes with source-generated modules and source-built runtime. Preserve its declared generation/compile/link separation, source-runtime `CcInfo` path and overlay fixes, then rerun using the production minimal archive and target-module integration. Inspect `main` and runtime undefined symbols, final library order, CRT/libc/builtins and linked output. Also exercise C-main interop. No new general ruleset is needed for this qualification.
5. **Verify separation.** A relocated minimal host executable compiles a module-free source with target runtimes/linker absent; importing an intrinsic module succeeds only when its external declared target module input is supplied. Final linking succeeds only with the target runtime/toolchain closure. The same host artifact must not embed one target's sysroot or static-link defaults.
6. **Keep external consumer integration scoped.** Reuse or improve an existing ruleset only under a separately agreed scope. A crossenv export is a separate composition interface, currently unproven; do not add it to the host archive as a shortcut.
7. **Requalify the manual publication path against the corrected artifact.** Preserve checksums/attestations, approved naming and explicit release gating. Prior bundled-archive test results do not qualify the minimal artifact. No release before approval and merge; this audit does not publish anything.

## Required acceptance scenarios

- Relocated host archive: `--version`, trivial `-c`, preprocessing and object inspection with no other compiler/linker on PATH; no target-fixed defaults or hidden target payload.
- Runtime: formatted I/O, allocation/arrays, math, `stop` failure status; object/archive inspection for C++ ABI dependencies and executable dependency inspection.
- Modules: `iso_c_binding`, `iso_fortran_env`, IEEE arithmetic; a user module consumed by a second compilation; preprocessing and include inputs; matching target-kind values.
- Linking: a Fortran-main object contains C `main`; Hermetic LLVM's C++ link action consumes it with the matching runtime and correct library order. C calls `bind(c)` Fortran and Fortran calls C; descriptor API via the declared `ISO_Fortran_binding.h`.
- Boundaries: missing external module/runtime cannot be supplied by an undeclared host installation; compile-only does not require a target linker/runtime; ordinary minimal LLVM tarball remains unchanged.
- Build portability: source archive mode and release configuration; Linux x86_64-musl first; each additional host/target independently qualified. No Windows, OpenMP, CUDA, quadmath or shared-link success is implied by native hello-world.

## Suggested short PR description after implementation

> Publish a minimal Flang host compiler alongside the existing LLVM prebuilts. Keep target intrinsic modules and runtime configuration in Hermetic LLVM so the compiler can be reused across target environments without embedding a sysroot or fixed link policy.

Describe final-link integration separately according to what has actually been demonstrated. Source-level viability is not an end-to-end test result.
