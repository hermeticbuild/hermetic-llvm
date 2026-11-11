# Microsoft STL for Windows MSVC: investigation and proposed plan

Status: proposal for agreement. No implementation or public API approved.
Investigated 2026-11-11 against refreshed `origin/main` at
`8a3f5bd77702fc0de58252e715404fcac1eed24e`. Scope follows [issue #878][878].

## Recommendation and decisions to agree

Add Microsoft STL as another value of the existing **C++ standard-library
constraint**, alongside libc++ and versioned GNU libstdc++. Keep libc++ as the
default. Microsoft STL is not a version of GNU libstdc++, and the Windows GNU
and MSVC target environments must remain separate.

Use the **matching headers and precompiled retail libraries already fetched by
`windows_support`**, rather than building Microsoft/STL from source in the first
implementation. Support Windows MSVC x86-64 and ARM64, with `/MD` and `/MT`,
through the existing native and cross toolchains. Preserve native Microsoft
stdio defaults for this selection; keep libc++'s ISO stdio policy unchanged.

Concrete decisions requiring agreement before implementation:

| Decision | Proposed answer | Reason / alternative |
| --- | --- | --- |
| Public selection | One new constraint value, candidate `@llvm//constraints/cxxstdlib:msvcstl` | Reuses existing platform selection. Exact spelling requires approval; `msvc` is shorter but confuses target ABI with library. No new `libstdcxx` version or boolean selector. |
| Default/platforms | Existing platforms and default stay libc++; document a user-defined MSVC+STL platform | Avoid a default ABI/library change. Additional convenience platforms would be additional public API, requiring separate approval. |
| Acquisition/version | Reuse pinned toolset headers and libraries as a matched unit | No independent STL version knob initially. Root overrides must remain internally consistent with compiler compatibility flags. |
| Linkage | `/MD` selects `msvcprt.lib`; `/MT` selects `libcpmt.lib` | Bazel `linkstatic` controls ordinary dependency linkage, not this CRT/STL choice. Mixed static STL/dynamic CRT is deferred. |
| Default-library ownership | Keep native header directives; select the explicit STL default in Bazel's existing MSVC default-library composition | Matches existing libc++ ownership, handles archive/foreign link scenarios, and keeps toolchain policy inspectable. Header-only autolink is a viable smaller alternative; see below. |
| Opt-outs | Preserve independent `nostdincxx` / `nostdlibxx`; selectively suppress STL default-library directives for the latter | Removing a linker flag alone is insufficient with Microsoft STL headers. Explicit library dependencies must still work. |
| Deployment | Declare DLLs explicitly in `/MD` test fixtures; document application redist requirement | No automatic application bundling API in the first change. Do not rely on runner-installed Visual Studio. |
| Dependency sequencing | C++ integration can proceed on current main; coordinate with #920 and CRT work, without silently adopting their APIs | Native C++ consumers are not blocked by Rust's final-link selection work. Rust qualification needs its own exact dependency revision. |

## What is already present

All repository links below are pinned to the investigated baseline unless a PR
or issue is explicitly named. Statements here describe source inspection, not
new end-to-end qualification.

### Selection and targets

[`constraints/cxxstdlib`][cxxconstraints] defines one `variant`, defaulting to
`libcxx`; values are libc++ plus versioned GNU libstdc++ values from the GCC
inventory. [`runtimes/cxxstdlib/BUILD.bazel`][cxxruntime] routes header paths, ABI
headers, library paths, and static/dynamic runtime files. GNU libstdc++ currently
routes on Linux, with its port restricted to supported Linux/glibc targets;
Windows is explicitly rejected at the routing boundary. Its MinGW source-file
inventory is not Windows runtime support.

[`platforms/declare_platforms.bzl`][platforms] explicitly pins existing
`windows_{x86_64,aarch64}_msvc` platforms to libc++ and UCRT. Generic Windows
platforms retain GNU ABI behavior; omitted ABI constraints also retain that
compatibility. `gnullvm` is a GNU-environment compatibility value for Rust, not
an alias for MSVC ABI. A new STL constraint must require **Windows + MSVC ABI +
UCRT + supported CPU**, not merely Windows or `compiler == "clang-cl"`.

[`toolchain/features/msvc/validation.bzl`][validation] currently rejects every
non-libc++ MSVC configuration. It also rejects legacy MSVCRT, retains unsupported
feature checks, and checks retail CRT requests. The new selection must update
this owning boundary. Unsupported STL selections on Linux, macOS, WASI, UEFI,
GNU Windows, and `gnullvm` must fail clearly rather than reach a default libc++
branch or silently change target environment.

### Existing Microsoft payloads

[`MODULE.bazel`][module] pins `windows_support` **0.4.1**, MSVC toolset
**14.50.35717**, an immutable Visual Studio installer manifest URL/integrity,
and Windows SDK NuGet packages **10.0.26100.7705** with individual integrities.
The SDK's extracted include-directory version is **10.0.26100.0**; it is not the
NuGet package version. The inspected toolset's retail redist payload is
**14.50.35710**, another distinct version.

At [`windows_support` v0.4.1, `43dce21da77d8cb4a486709e34f1d887e69058c6`][ws],
the MSVC repository traverses manifest dependencies, downloads VSIX ZIP payloads,
verifies supplied hashes, extracts them without executing the Windows installer,
and retains selected toolset include/lib and redist trees. It exposes
`msvc_include`, architecture-specific library directories, retail
`vc_redist_{x64,arm64}`, and separate `vc_redist_debug_*` targets. The generic
`headers_include` filegroup matches header suffixes and **omits extensionless
STL headers**; the directory target is the correct existing input.

[`runtimes/msvc/BUILD.bazel`][msvcruntime] already aliases the full VC include
and architecture-specific library directories. Default includes deliberately
use filtered VCRuntime/compiler ABI headers, COM headers, and SDK headers, so
libc++ remains the only default STL. Existing selected retail library subsets
already contain:

| Mode | Selected VC subset | Other existing inputs |
| --- | --- | --- |
| `/MD` | `msvcprt.lib`, `msvcrt.lib`, `vcruntime.lib` | UCRT/UM SDK libraries, common support, COM support |
| `/MT` | `libcpmt.lib`, `libcmt.lib`, `libvcruntime.lib` | Same classes of SDK/support inputs |

`msvcprt.lib` and `libcpmt.lib` are Microsoft C++ library inputs already present
for the libc++/Microsoft ABI-support path; their presence does not mean
Microsoft STL is currently selectable. COM and common archives such as
`legacy_stdio_definitions.lib`, `oldnames.lib`, `comsupp*.lib`, and
`exe_initialize_mta.lib` are separate support functionality. Do not remove them
with `nostdlibxx` or expose all debug/OneCore/Spectre libraries accidentally.

### Compile, link, archive, and bootstrap ownership

The owning path is:

```text
target platform constraints
  -> platform config predicates + toolchain resolution
  -> concrete exec-platform cc_toolchain, selected bootstrap stage
  -> Windows ABI routing
       -> clang-cl frontend / LLVM LIB archive personality / clang-cl final driver
       -> explicitly selected lld-link executable
       -> declared target SDK + CRT/support + selected C++ library
```

[`toolchain/llvm/llvm.bzl`][llvmtools] maps MSVC C/C++/assembly and link actions
to clang-cl; archives use LLVM's LIB personality. Both prebuilt and source-built
tool maps support these personalities. [`toolchain/declare_toolchains.bzl`][declare]
and [`toolchain/bootstrap/declare_toolchains.bzl`][bootstrap] select concrete
execution tools and append MSVC SDK/default-link arguments. The selector belongs
to target semantics, not execution-host OS.

An MSVC target uses `*-pc-windows-msvc` and Microsoft ABI/runtime semantics.
[LLVM's MSVC toolchain implementation][llvmmsvc] also supports the GNU driver.
hermetic-llvm's current contract uses [clang-cl][clangcl]. Adding another MSVC
driver mode is outside this feature. The executable's own build environment is
independent of that driver personality. [Clang's MSVC compatibility document][clangcompat]
also distinguishes ABI, language extensions, and compatibility options.

All six existing execution OS/CPU pairs are declared for MSVC targets:
Linux, macOS, Windows × x86-64, ARM64. Native Windows stage 0 uses the existing
GNU/MinGW-built LLVM prebuilt. Later stages build GNU-compatible Windows LLVM
execution tools. Selecting Microsoft STL for the **target** does not require
an MSVC-built LLVM execution archive or a change to release/bootstrap compiler
library policy. Source/bootstrap transitions must preserve that separation.

Most importantly, [`toolchain/cc_toolchain.bzl`][cctoolchain] sets both
`static_runtime_lib` and `dynamic_runtime_lib` to empty for MSVC. The effective
MSVC library composition is instead
[`normalized_default_libs`][msvcargs], containing selected CRT library search
paths and an explicit CRT `/DEFAULTLIB`, then
[`clang_cl_static_libcxx_default_lib`][args] with `/DEFAULTLIB:libc++.lib`.
Changing only the generic `runtimes/cxxstdlib` runtime filegroups would not
change actual MSVC final links.

The `runtime_stage` dimension controls construction dependencies.
`runtime_stage=stage0` disables normalized default libraries, while normalized
SDK compile arguments can remain. `stage1_hosted` supplies target C headers/CRT
for construction tools and omits the default C++ library. Separately,
`bootstrap_stage=stage0_prebuilt_seed` selects a prebuilt compiler for ordinary
target builds with their normal runtime policy. A precompiled STL should not
acquire a runtime-build transition or create a cycle through its own header
overlay/module-map tool.

Case handling is bound to the concrete execution toolchain. On Linux/macOS,
[`case_insensitive_vfs.bzl`][vfs] and MSVC argument composition provide explicit
header/library overlays; native Windows omits these generator dependencies to
avoid bootstrap cycles. A new VC STL include tree must participate when selected
on case-sensitive execution. Test actual Linux execution, including Windows
repository hosts dispatching remotely; a case-insensitive macOS filesystem
cannot prove that path.

## Upstream contracts that affect the design

### Components, versions, and license boundaries

Microsoft STL is Microsoft's C++ Standard Library implementation. UCRT supplies
C runtime facilities; VCRuntime supplies compiler/exception ABI support; SDK UM
libraries supply Windows APIs. `msvcrt.lib` in a modern MSVC toolset is part of
the modern CRT arrangement, not a request for hermetic-llvm's MinGW legacy
`windows/crt:msvcrt` selection. [Microsoft's CRT library reference][crtlibs]
documents the component separation.

The [Microsoft/STL source repository][stlreadme] uses Apache-2.0 WITH LLVM-exception.
That source license does not turn proprietary SDK/toolset payloads into a
redistributable public LLVM archive. Existing acquisition is per-consumer from
Microsoft; preserve the lazy MSVC EULA gate and immutable payload verification.
The hermetic-llvm README documents acceptance of both licenses. Source inspection
of windows_support 0.4.1 found enforcement of
`BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA`, but **no enforcement of
`BAZEL_WINDOWS_SDK_EULA` in its SDK repository rule**. Do not describe the latter
as an implemented gate. Changing license handling is separate from STL routing.

For redistribution, use the applicable [VS 2026 Build Tools terms][buildlicense],
[V14 runtime terms][redistlicense], and [Microsoft redistribution guidance][redist].
Debug CRT is not redistributable. Retail DLL deployment needs an appropriate
redist version/architecture; a successful link is not deployment. This plan does
not assert that every use or repackaging is licensed. No new vendored Microsoft
binary archive or release upload is proposed.

Keeping the shipped header and library versions together avoids a second
compatibility axis. The pinned header inspected in the direct probe requires
Clang >=19. Current Microsoft/STL `main` instead requires Clang >=22 in
[`yvals_core.h`][yvalscore]; it is not interchangeable with the pinned toolset.
The toolchain currently hardcodes `-fms-compatibility-version=19.50.35717` in
`toolchain/args/windows/msvc/BUILD.bazel`. Root-level toolset overrides therefore
need a compatibility/version check during qualification; do not bypass upstream
header guards or imply arbitrary overrides are supported.

[Microsoft's binary-compatibility rules][binarycompat] constrain toolset/redist
combinations and distinguish native object compatibility from MSVC `/GL`/`/LTCG`
artifacts. LLVM ThinLTO and MSVC LTCG are not interchangeable. Test the actual
Clang/lld versions advertised by hermetic-llvm (currently LLVM 21/22/23 families),
not only a modern host compiler.

### CRT mode, macros, native autolinking, and opt-outs

[`/MD` and `/MT`][mdmt] determine runtime selection and `_DLL`/`_MT`; debug modes
add `_DEBUG`. Microsoft STL derives additional layout and runtime decisions from
these macros. [`yvals.h`][yvals] emits mismatch records for runtime and iterator
debug level; [`use_ansi.h`][useansi] emits `msvcprt` or `libcpmt` default-library
directives, with debug/iterator suffixes where relevant. These records travel
inside an object/archive member (or LLVM bitcode metadata), not just final
command-line arguments.

Consequences:

- `/MD` with ordinary static dependencies is still dynamic CRT/STL; `/MT` with
  a shared application dependency is still a static runtime instance in each
  linked image. Do not derive CRT from `linkstatic` or equate `/MT` with a PE
  that imports no Windows DLLs.
- `-c dbg` should retain retail runtime and iterator level 0 unless the feature
  explicitly adds debug-CRT support later. PDB/debug-info generation is independent
  of `_DEBUG`, debug CRT, and debug STL ABI.
- Retain mismatch diagnostics. Do not use `/FORCE`, disable detect-mismatch
  macros, or add both CRT directories to make an inconsistent graph link.
- `_STATIC_CPPLIB`, nondefault `_ITERATOR_DEBUG_LEVEL`, `/MDd`, `/MTd`, manually
  overridden CRT flags, and mixed prebuilt CRT modes need explicit boundaries.
  Initially qualify only ordinary retail MD/MT with iterator level 0. Raw user
  flags cannot all be proven consistent at Bazel analysis time; document that
  limitation and keep compile/link diagnostics intact.
- The direct `/Zl` probe removed clang-cl's CRT and `oldnames` directives while
  **retaining** the header-emitted `msvcprt` directive. `_CRT_NOPRAGMA_LIBS` is
  reset by `use_ansi.h` unless building the CRT itself. Neither implements
  `nostdlibxx`.

[PR #903][903] introduced independent, target-scoped `nostdincxx` and
`nostdlibxx`, retaining explicit dependencies and C/CRT/unwind facilities. Under
Microsoft STL, omit the implicit header path for `nostdincxx`, but retain the
filtered ABI/COM/UCRT/SDK headers. For `nostdlibxx`, omit the toolchain STL
default and suppress relevant native STL default-library directives with
selective `/NODEFAULTLIB:<STL archive>` entries. Keep explicitly named library
inputs usable. Do not use bare `/NODEFAULTLIB`, which would suppress the CRT.
Decide the suppression list from the supported pinned library family and test
its boundaries; the direct probes established the selected retail name only.
Existing opt-out tests require Bazel 9+, and their libc++/libstdc++ string-based
runtime evidence must be extended to understand MSVC default-library policy.

**Proposed normal-link policy:** retain native directives and let Bazel also
name the selected STL default beside its existing CRT default. Both use the
same configuration-wide CRT choice; a mismatched archive should still fail.
The explicit default is a lazy search request, not whole-archive linkage. A
C-only executable must show no extracted STL implementation or MSVCP import.
Native directives keep ordinary third-party object semantics, while the Bazel
default handles header-free C++ references and external final-link adapters
that forward Bazel-owned flags. Arbitrary external linkers do not inherit this
policy. Do not insert retail import libraries into the generic
MSVC runtime provider and accidentally tie them to Bazel dynamic linkage.

**Alternative:** remove the libc++ default for Microsoft STL and rely entirely
on native directives plus declared search paths. Direct normal and ThinLTO
probes support this. It is smaller and naturally avoids a C++ default on C-only
links, but the header-free C++ case and foreign final link must then be given
an explicit supported contract. Choose this alternative if those cases are
explicit-only by design and the corresponding acceptance tests demonstrate it.
Neither option avoids the `nostdlibxx` directive problem.

### Stdio behavior is part of the feature

The current MSVC compile args unconditionally apply
`_CRT_STDIO_ISO_WIDE_SPECIFIERS` to align consumers with libc++.
[Issue #871][871] documents why selected legacy stdio implementations conflict
with that policy and records historical reproductions. [Issue #878][878]
explicitly requires native stdio defaults for Microsoft STL.

Gate the automatic ISO define on the libc++ selection; do not remove it
globally. Microsoft STL's own build uses
`_CRT_STDIO_ARBITRARY_WIDE_SPECIFIERS` because its implementation avoids the
affected patterns ([upstream build][stlcmake], [maintainer explanation][5166]).
Do not inject that macro into arbitrary application code. Allow an application
to request ISO behavior explicitly, while still rejecting a combination that
extracts conflicting legacy implementations. Test wide `L"%s"` behavior with
the appropriate narrow/wide input for each policy; `%ls` does not distinguish
the modes. Native-library interoperability needs actual non-inline stdio
calls, not merely a declared `legacy_stdio_definitions.lib` dependency.

### Source-building Microsoft STL is a separate port

The [upstream README][stlreadme] and [CMake build][stlcmake], inspected at
`e1ed302683e5e822f663fbb0f44cee7e9ddc6af0`, describe a Windows
development environment with recent Visual Studio, SDK, and tooling. The live
build checked here requires MSVC compiler 19.53.36829 and SDK 10.0.28000 or newer,
derives toolset paths from the compiler installation, enables MASM for x86/x64,
and names development DLLs with an `_oss` suffix. Its
[`stl/CMakeLists.txt`][stlbuild] has import-library objects, static-library
variants, satellite DLLs, assembly aliases, and other dependencies. Using
Clang to consume shipped STL is much narrower than porting this build.

A future source port would require a matched source revision, complete generated
headers/source inventory, assembly/alias and export handling, ABI/library naming,
SDK/VCRuntime integration, native differential tests, and an explicit deployment
policy for custom DLLs. It would still need non-STL Microsoft components.
It should not be smuggled into the first selectable-library patch.

## Consumers and final-link ownership

| Consumer/path | Required behavior |
| --- | --- |
| `cc_library` static/archive | Compile against one STL/CRT policy; preserve directives and mismatch records in members; no attempt to resolve them at archive creation. |
| `cc_binary`, `cc_test`, DLL, `cc_shared_library`, `cc_import` | Same selected STL/CRT inputs, correct import libraries, DEF/export behavior, no accidental libc++/libc++abi/libunwind or MinGW runtime. DLLs and executables need separate artifact checks. |
| Pure C and hosted construction tools | C/CRT/SDK/support remains available; no STL headers in C actions, no MSVCP import induced just by selecting a platform. Keep #914's explicit final CRT default for a `main` found only inside an archive. |
| Rust final link via rustc | MSVC target ABI needs a LINK-compatible linker (lld-link), declared SDK/runtime inputs and decoded forwarded options. Selecting Microsoft STL does not fix linker personality or CRT disagreement. |
| Rust final link via `cc_common.link` | Uses the C++ driver path; verify startup/CRT/native archives and Rust archive scanning, not the rustc direct-link assumptions. |
| Cargo `cc`/CMake build scripts | Build script runs in exec configuration; produced native objects target the requested MSVC platform. Preserve declared compiler/linker flags, do not discover host VS from PATH/INCLUDE/LIB. |
| Bindgen/libclang | Parsing language and action matter. C headers should not suddenly include STL. C++ binding probes must receive the selected STL path and compatible driver flags. |
| Go cgo, Zig C/C++ interop, foreign build rules | Qualify their actual ABI and driver/final-link contracts separately. Existing Windows cgo coverage is not evidence of MSVC STL consumption; GNU-environment consumers must stay on their existing path. |

Verified current dependency state:

- `hermeticbuild/rules_rs` main `e7d9e55555762e56b87454e7f17d70584f8968d8`
  provisions `hermeticbuild/rules_rust`
  `9fe9776dd52e84f3355d94773d950639705b6551` in
  [`rs/rules_rust.bzl`][rulesrs]. Thus rules_rs is not an independent final-link
  implementation to assume already fixes everything.
- That rules_rust revision's [`rust/private/rustc.bzl`][rulesrust] decodes
  `/clang:-Xlinker` and related forwarding for a selected direct MSVC linker.
  Its own comment states that it does not reproduce compiler-driver runtime
  selection or expand resource-directory behavior. Explicitly forwarded
  default-library and suppression options fit that interface; test resulting
  rustc/linker arguments and declared action inputs.
- [rules_rust #92][rust92] remains open at
  `100616343e949f6744c5f01733cc42bf36c86d5e`: automatic selection of declared sibling
  lld-link when the C++ toolchain uses clang-cl is in flight. A caller explicitly
  selecting a compatible Rust linker is a different path. Do not claim the
  ordinary downstream default is fixed by this STL feature.
- Current rules_rs [`rules_rust_bindgen.bzl`][bindgen] asks for a C compile action
  and preserves `--driver-mode=cl` for clang-cl. Consequently a future C++ STL
  bindgen test must establish how C++ mode obtains C++-only defaults; do not solve
  that by exposing STL headers in all C actions.

Rust `+crt-static` must agree with the C++ configuration-wide `/MT` choice for
native dependencies and their C++ runtime. Merely making `libcmt.lib` searchable
does not repair `/MD` objects, `_DLL`-dependent STL declarations, or mixed runtime
state. Across DLL/FFI boundaries, test ownership explicitly: allocation/free in
the same runtime, exception handling only across supported C++ boundaries, and
no C++ exception unwinding through Rust ABI. C ABI boundaries do not by
themselves eliminate CRT/stdio compatibility requirements.

## Merged, in-flight, and historical work

| State at investigation | Relevant work | Planning consequence |
| --- | --- | --- |
| Merged in baseline | #903 C++ opt-outs, #914 selected CRT default, #868 common support, #853 native-Windows overlay exclusion, #718/#726 driver/libc++ path, #727 native Windows execution | Reuse these contracts and preserve their regressions. Main now also includes #934 Bazel 9 CI, #935 prebuilts, #936 registration-source fetch avoidance. |
| Open | [#920][920], head `316a731fa86d026bee6b37e76f74f4cbb025d578`; windows_support [#21][ws21], head `0fbdd22ae5e23c72c6411132a2be9c0653dd8b36` | Move existing six filtered subsets from action-time copies to source directories; not a prerequisite for STL payload acquisition. Coordinate names/representation to avoid duplicate work. |
| Open | [#745][745], head `e6b7cc7c2e24cf108f2097f5d7351c32f2e37a2e` | Proposes graph-wide CRT build setting and target-local conflict checks. Do not document that proposed setting as shipped or adopt its public API without agreement. |
| Open | [#857][857], head `227c58678ff66a7076f30fb6d8e17a3487119517` | Exposes both retail CRT directories for Rust linking. Makes files available, not graph consistency. Not the recommended dependency for a clean STL policy. |
| Open | #728/#729 header layering/parsing, #818 header search | Related surfaces; do not make modules/layering a hidden prerequisite or broaden supported features without proof. |
| Historical / separate | Existing MSVC-driver, libc++, support-library, native-flags, Windows-exec-overlay and Rust-linker worktrees | Source branches are not shipped state. The current user checkout `cerisier/pr914-msvc-crt-regression` at `3043a64c` has unrelated untracked files; no changes made there. |
| Open scope owner | [#878][878]; separate optional libc++ stdio issue [#871][871] | Native STL selection and stdio interoperability are this feature; optional non-ISO libc++ is not a blocker. |

## Proposed implementation sequence

1. **Agree selection and behavioral contract.** Approve only the new constraint
   spelling and first-cut matrix above. Decide explicit default versus native-only
   autolink; proposed default is explicit selection plus preserved directives.
   Keep existing public defaults and independent opt-outs. No new CRT, source-STL,
   stdio, or deployment knobs as incidental additions.
2. **Finish narrowly targeted baseline probes.** Use exact pinned payloads with
   shipped LLVM families, existing restricted library subsets, native/ISO stdio,
   and both CRT modes. The direct probes below establish feasibility; add the
   baseline failing configured target/regression before editing routing.
3. **Wire the existing payload at the owning layers.** Add the approved constraint
   and MSVC-only validation; route C++ default headers, ABI headers, and library
   search selection. For MSVC STL, ABI support remains VCRuntime, never libc++abi
   or libunwind. Generalize the MSVC default-library selection in the actual
   `normalized_default_libs` path. Reuse current filtered retail subsets first;
   add only a proven missing support archive if broader probes require it.
4. **Preserve header and opt-out boundaries.** Use full `msvc_include` only for
   selected C++ default headers, including extensionless files. Keep filtered
   C/ABI headers available under `nostdincxx`. Determine include ordering with
   `-H`/preprocessor traces: Clang builtin headers, VC headers, and UCRT headers
   must each come from the intended tree. Current libc++ uses `/clang:-isystem`
   before builtins for wrappers; do not blindly impose that reason on Microsoft
   STL. Native `/imsvc` ordering is a candidate to test, not an assumed alias.
   Add selected headers to non-Windows-exec overlays without reintroducing
   an overlay-generator bootstrap cycle or leaking them through opt-out paths.
   Implement selective STL default suppression and explicit-input escape hatch.
5. **Apply stdio policy and qualify complete links.** Gate the existing automatic
   ISO define on libc++; keep native defaults for Microsoft STL. Exercise archive,
   alwayslink, executable, shared-library/import-library and ThinLTO paths. Retain
   user-facing unsupported-feature errors, runtime stages, and resource-directory
   ownership. Check `no_exceptions`/`no_rtti` header behavior; `_HAS_EXCEPTIONS`
   may need explicit alignment only if a real probe shows existing flags are
   insufficient.
6. **Qualify exec/bootstrap and consumers.** Linux remote and macOS cross builds,
   native Windows actions, x64/ARM64 targets, prebuilt and source-built LLVM paths.
   Audit the target-to-exec transition so host tools retain their own library.
   Then Rust/C++ interoperability with an explicitly pinned working linker route;
   record prerequisite PR revisions instead of attributing them to this patch.
7. **Document supported behavior and evidence.** Update README selection example,
   support matrix, CRT/`linkstatic` distinction, native stdio behavior, opt-outs,
   DLL deployment and deferred features. Keep concise PRs around ownership
   boundaries; acceptance evidence belongs in linked task notes where appropriate.

## Acceptance matrix and observable evidence

Do not treat a successful hello-world compile as full support. Minimum merge
criteria for the claimed matrix:

| Scenario | Required observation |
| --- | --- |
| x64/ARM64 × `/MD`/`/MT` | Correct COFF machine; selected header implementation (`_MSVC_STL_VERSION`, absence of `_LIBCPP_VERSION`/`__GLIBCXX__`); expected `.drectve`/LLVM linker metadata and CRT/iterator mismatch records. |
| C++ behavior | String/vector/iostream, exceptions/RTTI, `new`/`delete`, filesystem and threads/atomic wait; at least one modern non-inline facility. This exercises runtime and possible satellite DLL dependencies. |
| C-only / main-in-static-archive | Existing startup fix retained; no default STL header path for C, no MSVCP import or unnecessary STL extraction. |
| Archive and DLL composition | Static archive, alwayslink, `cc_shared_library`, explicit/generated DEF, import library, executable using DLL; inspect imports/exports and archive contents. Runtime ownership across DLL boundary exercised explicitly. |
| Link mode independence | `linkstatic=True` and `False` in each CRT mode preserve configured MD/MT choice. DLL output does not silently select another CRT. |
| Debug/build modes | fastbuild/opt/dbg and PDB variants retain retail CRT/iterator policy; no debug DLLs. Unsupported debug CRT/custom iterator family has clear diagnostics or documented raw-flag boundary. |
| ThinLTO | Inspect frontend bitcode, index/backend args, final link and COFF directives; verify MSVC STL is ordinary native archive/import-library input, with no claim of MSVC LTCG compatibility or cross-library IR optimization. |
| Independent opt-outs | All four nostdincxx/nostdlibxx combinations, C++-only header defaults absent when requested, selective default suppression present, C/CRT remains; explicit replacement header/archive still works; exec tool unaffected. |
| Stdio and native interop | Native MSVC-built C++ archive plus STL application; actual Rust `libc::sscanf` extraction and C++ logging; native wide-format result; explicit ISO-only application works; conflicting ISO+legacy closure still fails. |
| Hermeticity | `aquery --include_param_files` shows declared exact compiler/linker, SDK/header/CRT/STL inputs, overlay where needed, no host VS/SDK discovery. Poison `INCLUDE`/`LIB` with sentinel paths and ensure they are not consumed. |
| Execution | Native Windows x64 and ARM64 runtime tests, MD test with explicit matching retail redist DLLs or controlled supported installation, MT test with no dynamic VC/UCRT import. Wine is useful supplemental x64 evidence, not native/ARM64 qualification. |
| Cross and bootstrap | Linux remote and macOS local/cross action execution; Windows-host local/remote action path; stage0 and source-built stages use intended tool map, no target STL leakage into GNU Windows exec compiler builds. Claim later stages only after actual required artifacts/actions pass. |
| Negative platform/features | Reject STL on non-Windows/non-MSVC/legacy-MSVCRT/unsupported CPU and unsupported features. Keep GNU libstdc++ Windows rejection, libc++ defaults, MinGW/gnullvm, Linux libc++/libstdc++ and macOS paths intact. |

Reuse existing `e2e/rules_cc/windows_msvc_*` fixtures and artifact tests, including
the mixed C/assembly/C++ and CRT-default probes; extend with targeted STL cases
instead of duplicating their entire matrix. Extend
`tests/cxxstdlib_settings/contract.bzl` to inspect the new semantics rather than
only recognize libc++/libstdc++ strings. Existing
`windows_msvc_native_exec_validation.sh` executes a matching-architecture `/MT`
test; `/MD` execution needs explicit additional coverage and declared redist.

For implementation verification, from `e2e/rules_cc`, start with the project
default `bazel build --config=remote //:main`, then targeted configured STL
targets and `aquery`/artifact inspection. Final target names depend on the agreed
API; do not publish commands that pretend proposed labels already exist.
Use the same failing baseline reproduction after the change. Cross builds prove
artifact generation; only runtime tests prove behavior.

Deferred: source-built/custom STL DLLs; x86-32/ARM64EC; GNU/MinGW or gnullvm
Microsoft STL; mixed static STL/dynamic CRT; debug CRT/iterator variants;
sanitizers/coverage/FDO; modules/header parsing/layering support; automatic user
application DLL bundling; new MSVC-built LLVM exec releases. These are independent
ports or policy expansions, not required to expose the current retail library.

## Evidence produced during this investigation

Source and GitHub inspection used `git fetch origin`, `git show`, `rg`,
`gh pr view`, and `gh issue view`. Exact baseline and dependency revisions are
recorded above. The source checkout was preserved. No Bazel implementation,
new public API, PR, or fresh full Bazel build was produced.

The coordinating agent ran disposable direct probes on macOS ARM64 with
Homebrew Clang/lld **22.1.1**, cached MSVC **14.50.35717** and SDK include tree
**10.0.26100.0**. Source/objects/PE artifacts were retained locally in
`/tmp/hermetic-llvm-msvc-stl-probe.q7W2w0` (temporary evidence, not a durable
artifact URL). The test program uses `<iostream>`, `<stdexcept>`, `<string>` and
throw/catch. Direct compile/link commands select the MSVC target triple,
`/X /EHsc /std:c++20`, `/MD` or `/MT`, explicit VC/UCRT/shared/UM/WinRT include
directories and explicit library directories; compatibility version is
`19.50.35717`.

Observed results, **not Bazel integration or native runtime qualification**:

- x64 and ARM64, each MD/MT, compiled and linked. Repeating with only replicas
  of the current three-library selected VC CRT subset plus existing common/COM
  support and SDK library directories also linked.
- COFF directives name `msvcprt.lib` for MD and `libcpmt.lib` for MT, with the
  appropriate runtime/iterator records. MD PE imports include MSVCP140,
  VCRUNTIME140 and UCRT; MT test PEs import only KERNEL32.
- Native stdio plus a header-free C `sscanf` shim linked in all four tuples.
  Explicit ISO plus that shim failed with stdio mismatch values 1 versus 0.
  ISO STL use without the legacy shim linked. This exercises actual legacy
  extraction but is not the requested real Rust e2e or runtime formatting test.
- Selective `/NODEFAULTLIB:msvcprt.lib` or `libcpmt.lib` made the same C++ object
  fail with unresolved STL symbols; adding the selected library by explicit
  pathname restored successful links in all four tuples. Thus selective
  suppression can preserve explicit-library use.
- C-only `int main(void){return 0;}` compiled with `/Zl` and filtered C headers
  linked in all four tuples with explicit matching CRT and STL `/DEFAULTLIB`
  options. MD imports VCRUNTIME/UCRT without MSVCP; MT imports only KERNEL32.
  This confirms lazy explicit STL defaults for this C-only fixture.
- x64 MD `/Zl` preserved `DEFAULTLIB:msvcprt.lib` and mismatch directives while
  removing clang-cl's default `msvcrt.lib` and `oldnames.lib` directives.
- x64 MD with `/clang:-flto=thin` retained default-library/mismatch information
  in LLVM `!llvm.linker.options`; lld-link linked the bitcode using the restricted
  subsets, with expected runtime imports. Bazel's separate ThinLTO index/backend
  pipeline remains untested for the proposed selection.
- An x64 MD fixture using vector/string/iostream compiled with exceptions/RTTI
  enabled and disabled. `/EHs-c- /clang:-fno-rtti` removed compiler exception/RTTI
  macros, while pinned VC headers still defined `_HAS_EXCEPTIONS=1`. An explicit
  `_HAS_EXCEPTIONS=0` variant also compiled. This is a macro/compile observation;
  behavior and ODR compatibility across dependencies remain unqualified.

Not demonstrated here: native execution; Linux case-sensitive execution; shipped
LLVM 21/22/23 integration; source-bootstrap qualification; complete STL surface
and satellite DLL closure; `no_exceptions`/`no_rtti` runtime behavior;
real Rust/Cargo/bindgen use; configured Bazel opt-out and invalid-platform
regressions. Those are explicit
implementation acceptance tasks, not reasons to widen this research patch.

## Paste-ready eventual PR motivation

> Windows projects that exchange C++ objects with native MSVC dependencies need
> the Microsoft STL environment. Add an explicit Windows MSVC C++ library
> selection using the already pinned Microsoft toolset, while preserving libc++
> defaults and configuration-wide CRT behavior. The Microsoft selection uses
> native stdio defaults and retains independent C++ header/library opt-outs.

This paragraph describes the intended result, not an implemented change.

[878]: https://github.com/hermeticbuild/hermetic-llvm/issues/878
[871]: https://github.com/hermeticbuild/hermetic-llvm/issues/871
[903]: https://github.com/hermeticbuild/hermetic-llvm/pull/903
[920]: https://github.com/hermeticbuild/hermetic-llvm/pull/920
[745]: https://github.com/hermeticbuild/hermetic-llvm/pull/745
[857]: https://github.com/hermeticbuild/hermetic-llvm/pull/857
[ws21]: https://github.com/hermeticbuild/windows_support/pull/21
[rust92]: https://github.com/hermeticbuild/rules_rust/pull/92
[module]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/MODULE.bazel
[cxxconstraints]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/constraints/cxxstdlib/cxxstdlib_versions.bzl
[cxxruntime]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/runtimes/cxxstdlib/BUILD.bazel
[platforms]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/platforms/declare_platforms.bzl
[validation]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/features/msvc/validation.bzl
[msvcruntime]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/runtimes/msvc/BUILD.bazel
[msvcargs]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/args/windows/msvc/BUILD.bazel
[args]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/args/BUILD.bazel
[cctoolchain]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/cc_toolchain.bzl
[llvmtools]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/llvm/llvm.bzl
[declare]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/declare_toolchains.bzl
[bootstrap]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/toolchain/bootstrap/declare_toolchains.bzl
[vfs]: https://github.com/hermeticbuild/hermetic-llvm/blob/8a3f5bd77702fc0de58252e715404fcac1eed24e/case_insensitive_vfs.bzl
[ws]: https://github.com/hermeticbuild/windows_support/tree/43dce21da77d8cb4a486709e34f1d887e69058c6/windows/private/extensions
[rulesrs]: https://github.com/hermeticbuild/rules_rs/blob/e7d9e55555762e56b87454e7f17d70584f8968d8/rs/rules_rust.bzl
[rulesrust]: https://github.com/hermeticbuild/rules_rust/blob/9fe9776dd52e84f3355d94773d950639705b6551/rust/private/rustc.bzl
[bindgen]: https://github.com/hermeticbuild/rules_rs/blob/e7d9e55555762e56b87454e7f17d70584f8968d8/rs/rules_rust_bindgen.bzl
[crtlibs]: https://learn.microsoft.com/en-us/cpp/c-runtime-library/crt-library-features?view=msvc-170
[mdmt]: https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library?view=msvc-170
[binarycompat]: https://learn.microsoft.com/en-us/cpp/porting/binary-compat-2015-2017?view=msvc-170
[redist]: https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files?view=msvc-170
[buildlicense]: https://visualstudio.microsoft.com/license-terms/vs2026-ga-diagnostic-buildtools/
[redistlicense]: https://visualstudio.microsoft.com/license-terms/vs2026-ga-visualcpp-v14-redist-runtime/
[stlreadme]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/README.md
[stlcmake]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/CMakeLists.txt
[stlbuild]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/stl/CMakeLists.txt
[yvalscore]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/stl/inc/yvals_core.h
[yvals]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/stl/inc/yvals.h
[useansi]: https://github.com/microsoft/STL/blob/e1ed302683e5e822f663fbb0f44cee7e9ddc6af0/stl/inc/use_ansi.h
[5166]: https://github.com/microsoft/STL/issues/5166
[clangcl]: https://clang.llvm.org/docs/UsersManual.html#clang-cl
[clangcompat]: https://clang.llvm.org/docs/MSVCCompatibility.html
[llvmmsvc]: https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/clang/lib/Driver/ToolChains/MSVC.cpp
