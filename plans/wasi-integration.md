# WASI integration implementation plan

Status: structure approved; implementation authorized, starting with semantic
restructuring and a committed review checkpoint before subsequent steps.

Review baseline: PR #143, commit `6dee40b6ea38f8027b5596edd4e7d78b7d427f1c`.
Branch: `cerisier/wasi-integration-review`.
Worktree: `/Users/corentinkerisit/.codex/worktrees/wasi-integration-review/hermetic-llvm`.

The first implementation commit preserved generated compile/link behavior while
changing argument-group ownership and variant routing. The second checkpoint
incorporates the approved critique: hosted-C header composition, explicit thread
model and target-feature groups, and libc-owned source-language flags. The third
checkpoint separates CRT artifacts from libc archives. Header-order changes and
the constraint rename remain subsequent work. Public API beyond the approved
structure still requires Corentin's explicit agreement.

## First review checkpoint (629e81b2)

Implemented the semantic restructuring: top-level linker selection, explicit
libc-header and compilation-default slots, scoped P1/P1-threads/component
implementations, and separate startup/library argument ownership. CRT files
still share the libc directory; the command lines and inputs are preserved.

New implementation targets have restricted visibility. Removed PR-only argument
names `headers`, `runtime_compile_flags`, and `component_linker`; the older
generic `args:fuse_ld` label remains an alias for generic LLD selection.

Baseline and post-change action comparisons cover:

- 6,518 compile/link actions beneath the three Wasm/WASI test targets.
- Stage 1 and hosted stage 1 compile/link probes for all four WASI variants.
- Complete Linux x86-64 glibc/musl and freestanding wasm64 compile/link probes.

Action keys, ordered arguments, input/output paths, environments, and execution
properties match exactly in these comparisons. The stage probes were temporary
verification fixtures; they are not additions to the public test/API surface.
The capture/comparison scripts and JSON/log evidence are under
`/tmp/wasi-semantic-*` in this session.

Checks completed at this checkpoint:

- Baseline: `bazel test --config=remote //tests/wasm:wasm_test
  //tests/wasm:wasi_p1_test //tests/wasm:wasi_variants_test` passed all three
  tests using the normal pinned LLVM 23.1.2 repository, without source overrides.
- After restructuring: the same test command plus
  `//internal_tools:buildifier.check` passed all four checks. The Wasm tests
  were cache hits, consistent with unchanged action keys.
- In `e2e/rules_cc`, `bazel build --config=remote //:main` passed; the resulting
  arm64 Mach-O executable printed `Hello, World!`.
- `bazel build --config=remote --platforms=//platforms:wasi_wasm32_p1
  //toolchain/args/wasi/components:linker` failed with the expected explicit
  target-incompatibility diagnostic. P2/P3 selection succeeds in the test graph.
- Focused read-only review found no issues; formatting and `git diff --check`
  passed. No new Windows execution or additional LLVM-version testing is claimed.

Suggested PR description:

> WASI's argument wiring mixed startup lookup with library lookup and selected
> component variants inside the generic linker implementation. Give these
> responsibilities stable semantic slots and scoped WASI implementations, as
> required by the toolchain design, while preserving existing build behavior.

## Second review checkpoint: semantic groups and hosted headers

Replaced the first checkpoint's generic compilation-default bucket with
`thread_model` and `target_features`. WASI libc headers now enter through
`wasi_hosted_c_toolchain_args`, shared by complete applications and hosted
stage 1. Stage 0 retains explicit libc header dependencies. Removed propagated
`-fdefer-ts`; wasi-libc retains its own flag, and its affected `bottom_half`
implementation now owns the LLVM 22 minimum-version restriction.

Compared against `629e81b2` using the normal pinned LLVM 23.1.2:

- Of 6,518 compile/link actions, 4,417 are unchanged. Another 1,805 libc
  compilations lose a duplicate `-fdefer-ts`, and 296 other runtime compilations
  lose that unintended flag. Ordered arguments have no other differences;
  inputs, outputs, environments, and execution properties match.
- All four variants' stage 1 and hosted stage 1 compile/link checks pass
  analysis. Only P2/P3 compilations lose the propagated syntax flag. Complete
  Linux glibc/musl and freestanding wasm64 checks remain unchanged.
- `bazel test --config=remote //tests/wasm:wasm_test
  //tests/wasm:wasi_p1_test //tests/wasm:wasi_variants_test` passed (cache hits).
  `bazel test --config=remote //internal_tools:buildifier.check` passed after
  correcting attribute order. In `e2e/rules_cc`,
  `bazel build --config=remote //:main` passed.
- Focused read-only review found no actionable issues. Temporary stage fixtures
  were removed. Comparison evidence remains under `/tmp/wasi-groups-*` and
  `/tmp/wasi-semantic-groups-*`; no permanent probe/API was introduced.

The relocated version gate was reviewed in source, not exercised with an older
LLVM checkout. No new Windows or P2/P3 runtime-execution coverage is claimed.

Suggested PR description:

> WASI thread policy and target features need distinct semantic owners; libc
> source syntax must not leak into unrelated runtime compilations. Route those
> policies through scoped WASI implementations, reuse hosted-C composition for
> libc headers, and keep C defer requirements with wasi-libc.

## Third review checkpoint: CRT directory separation

WASI now participates in the existing `//runtimes:crt_objects_directory`
selection. Its private implementation stages `crt1.o`, `crt1-command.o`, and
`crt1-reactor.o` in `generated/crt`; the library directory retains its 16 archives
and no startup objects. `wasi:default_startfiles` reuses the generic
`crt_search_directory` argument group. No public target or build setting was
added. Raw CRT extraction and P2/P3 metadata embedding remain unchanged.

Evidence against `1aff6e25`, with the pinned LLVM 23.1.2:

- Of 6,518 compile/link actions, 6,512 are unchanged. Six WASI application
  links change only the CRT `-B` path and add the CRT directory as a declared
  input. Library `-L` paths, compiler resource directories, ordered remaining
  arguments, outputs, environments, and execution properties are unchanged.
  Captured CRT generation actions also remain unchanged.
- All eight captured Wasm/WASI linked artifacts have identical SHA-256 hashes
  before and after, including command, reactor, threaded P1, and P2/P3 outputs.
- Temporary remote driver checks cover all four variants, command/reactor, and
  default/`-nostartfiles`/`-nodefaultlibs`/`-nostdlib`: 32 invocations preserve
  linker arguments except the selected CRT path. Startup and default-library
  suppression behave as before. These dry runs do not establish P2/P3 reactor
  execution support. Temporary fixtures were removed before commit.
- Inspected directory contents: exactly three CRT objects and 16 separate
  archives for each variant. Reusing the generic group also supplies `-B` and
  the declared CRT input to ThinLTO indexing; its action graph was checked.
- `bazel build --config=remote --features=thin_lto
  --platforms=//platforms:wasi_wasm32_p1 //tests/wasm:wasi_command` fails in
  ThinLTO indexing because `wasm-ld` rejects the existing `-plugin-opt` arguments.
  Repeating the same command with the three code files restored temporarily to
  `1aff6e25` reproduces the same failure. This pre-existing ThinLTO issue remains
  outside CRT separation; successful ThinLTO builds are not claimed.
- `bazel test --config=remote //tests/wasm:wasm_test
  //tests/wasm:wasi_p1_test //tests/wasm:wasi_variants_test` passed before and
  after (test cache hits). `bazel test --config=remote
  //internal_tools:buildifier.check` and the `e2e/rules_cc`
  `bazel build --config=remote //:main` check passed.
- Focused read-only review found no actionable issues. Action, driver, artifact,
  and build evidence is stored under `/tmp/wasi-crt-*` for this session.

Suggested PR description:

> WASI startup lookup still depended on the libc archive directory despite
> having its own semantic group. Stage CRT objects separately and select them
> through the existing runtime CRT directory contract, preserving Clang's
> command/reactor selection and the generated binaries.

## Intended contract

WASI is the target system interface; wasi-libc implements the C library on top
of it. Preserve separate freestanding Wasm and WASI platforms. A WASI variant
selects a coherent target triple, libc headers, libc implementation, startup
objects, compiler support libraries, and final artifact format.

Retain the PR's wasm32, C, static-libc scope and SDK 34 source pin. Preserve
Clang's ownership of default-library selection and command/reactor startup
selection. Compiler-rt remains in the existing Clang resource-directory
machinery. Compiler resource headers must belong to the selected compiler,
not to the target libc or a different LLVM source generation.

Authoritative local design references:

- `toolchain/README.md`: stable semantic groups, package ownership, downward
  specialization, separate compiler-personality and execution-platform axes.
- `toolchain/runtimes/README.md`: staged runtime argument compositions.
- `toolchain/bootstrap/README.md`: compiler stages and resource-header ownership.
- `toolchain/features/clang_cl/README.md`: separation of target, runtime,
  personality, and explicit protocol bridges.

External implementation references:

- https://github.com/WebAssembly/wasi-libc/tree/wasi-sdk-34
- https://github.com/llvm/llvm-project/blob/main/clang/lib/Driver/ToolChains/WebAssembly.cpp

Resolve the driver reference to the exact LLVM revisions under test when
recording evidence; current upstream main is not proof for all supported versions.

## 0. Approved semantic tree

Recommendation: implement WASI through the existing composition hierarchy, with
stable semantic slots and scoped concrete implementations. Correct ownership
before changing behavior. Do not create a second complete WASI toolchain
composition, normalize unrelated platforms, or introduce a generic framework.

The structure and labels below were approved for implementation. New
composition helpers should be private or visible only to their actual consumers.
Existing public labels need an explicit compatibility decision before removal.

### Proposed ownership and naming

| Owner | Proposed target/responsibility |
| --- | --- |
| `//toolchain` | `linker`, `thread_model`, `target_features`, existing `default_startfiles` and `default_libs`: select target-OS implementations. `wasi_hosted_c_toolchain_args` composes the WASI libc-header arguments for hosted consumers. |
| `//toolchain/runtimes` | Compose the same semantic responsibilities for each runtime stage; preserve which headers, libraries, and flags are available at that stage. |
| `//toolchain/args` | Reusable concrete implementations such as LLD selection and CRT search arguments; no new WASI variant dispatch. |
| `//toolchain/args/wasi` | Same-named semantic implementations/selectors; common WASI libc include/search arguments and routing to the applicable WASI profile. |
| `//toolchain/args/wasi/p1` | Single-thread model for P1 runtime compilation. |
| `//toolchain/args/wasi/p1_threads` | POSIX thread model, pthread mode, and local-exec TLS; separate atomics target-feature implementation. |
| `//toolchain/args/wasi/components` | Shared P2/P3 component linker and single-thread-model implementations; explicitly limited to component variants. |
| `//runtimes/wasi` and `@wasi_libc` | Headers, CRTs, archives, metadata generation, and libc implementation requirements. |
| Existing WASI execution toolchain | Select native `wasm-tools`/`wasm-component-ld` binaries independently of the Wasm target profile. |

`components` is a shared implementation scope for the existing P2/P3 group, not
a new selectable ABI. Add separate P2/P3 argument packages only if their
argument semantics differ. Variant-specific WIT and libc sources remain selected
in the artifact-building layer. Common arguments stay at their common scope;
do not duplicate them merely to create matching directory trees.

Selection for linker choice should read:

```text
//toolchain:linker
  target OS = wasi -> //toolchain/args/wasi:linker
    p1 / p1_threads -> existing generic LLD implementation
    p2 / p3        -> //toolchain/args/wasi/components:linker
  other OS routes  -> their existing linker implementation
```

The complete staged runtime composition separately selects its linker according
to its existing role; do not replace its explicit LLD use with the complete
application route without evidence that the stage requires component output.
One semantic name does not imply identical implementation at every stage.

### Concrete amendments to the PR

1. Remove WASI dispatch from generic `args:fuse_ld`. Route linker selection
   through `//toolchain:linker` and the WASI selector. Keep current non-WASI
   linker arguments and ordering unchanged.
2. Replace the ambiguous WASI `headers` argument-group name with
   `libc_headers_include_search_paths` in the WASI argument package. Reference
   it through `wasi_hosted_c_toolchain_args`, following the existing hosted-C
   composition in the complete and stage1-hosted paths. Do not introduce a
   global libc-header slot that only serves WASI. Preserve header position and
   runtime-stage dependency boundaries; do not choose a new include flag here.
3. Split `default_startfiles` from `default_libs` as described in step 1 below.
   Use WASI semantic wrappers/selectors and reuse generic CRT-search mechanics.
4. Replace the first checkpoint's `default_compile_flags` with `thread_model`
   and `target_features` semantic groups selected at the toolchain level and
   implemented by the applicable WASI profile. Keep pthread mode and local-exec
   TLS with the thread model for now. Put atomics in target features. Both groups
   are empty for other OSes and consumed only by the staged runtime composition,
   preserving application behavior. Do not add user-selectable settings.
5. Remove libc source-language requirements such as `-fdefer-ts` from the broad
   runtime-toolchain bundle where they are already supplied by wasi-libc's own
   `COMMON_COPTS`. Keep the required LLVM compatibility restriction with the
   affected libc implementation. Verify that no other current consumer relies
   on that accidental propagation before removing it.
6. Move the concrete component linker arguments and their declared executable
   input into `wasi/components:linker`, with compatibility restricted to P2/P3.
   Keep host-tool selection in the existing execution toolchain.
7. Do not rename artifact targets such as `c` or `crt1_command` just to mirror
   argument-group names. Their semantic role is already an archive or object.

### Acceptance for the structural change

- A named slot has the same responsibility in complete and staged compositions;
  empty implementations remain legitimate at stages without that dependency.
- Platform/profile selection flows through the declared hierarchy. A concrete
  leaf does not redispatch to a peer variant or a different OS.
- Common implementations are reused; concrete component-only behavior is
  constrained at its owning implementation, not only at its current caller.
- Hosted libc-header composition follows the existing platform grouping, as
  explicitly agreed during review. Thread model and target features use named
  semantic slots, not a generic compilation-default bucket.
- No new public API is exposed incidentally through package-wide visibility.
- Compare before/after action arguments and inputs. Separate intentional changes
  (CRT-directory split, header correction if proved, removal of libc-only syntax
  flags from other runtimes) from semantic-preserving routing and renaming.

## 1. Align startup and libc ownership (implemented)

Proposed change:

1. Separate the WASI CRT directory from the libc library directory.
2. Add a WASI implementation to the existing
   `//runtimes:crt_objects_directory` selection and its compatibility gate.
3. Route `//toolchain:default_startfiles` through the WASI
   `default_startfiles` semantic implementation, which reuses the existing
   `//toolchain/args:crt_search_directory` implementation.
4. Keep library lookup (`-L`) in WASI's `default_libs`; move CRT lookup (`-B`)
   out of that group.
5. Retain raw CRT object extraction and component metadata embedding. Do not
   introduce a relocatable-link step that could discard exported entry names.

Files: `runtimes/wasi/wasi.BUILD.bazel`, `runtimes/wasi/BUILD.bazel`,
`runtimes/BUILD.bazel`, `toolchain/args/wasi/BUILD.bazel`, `toolchain/BUILD.bazel`.

Acceptance:

- The normal driver selects `crt1-command.o`; reactor mode selects
  `crt1-reactor.o`. Both remain declared action inputs.
- `-nostartfiles`, `-nodefaultlibs`, and `-nostdlib` retain the selected driver's
  behavior. Compare driver invocations, not merely successful exit status.
- Resource-directory builtins and final command/reactor behavior are unchanged.
- Staged runtime toolchains preserve their existing dependency boundaries.
- Ordinary `-l...` lookup continues to work.

## 2. Establish native WASI header semantics before changing flags

The PR uses explicit `-isystem`, as existing libc paths on main do. That is
not sufficient evidence of matching the native WASI driver search order.
PR #819's manual header-component work is relevant but remains a separate
change; inspect its current state rather than assuming it is merged.

Proposed sequence:

1. Use the same compiler, target variant, and wasi-libc headers for both a
   reference sysroot invocation and hermetic-llvm's invocation.
2. Capture driver arguments and effective include search order. Account for
   explicit compiler-resource insertion in the selected toolchain.
3. Compare compiler builtin headers, public libc headers, user include paths,
   and supported frontend actions. Check shadowing and `include_next` behavior.
4. If different, reproduce the consequential difference before editing, then
   express the native WASI ordering through the existing header-component
   approach. Choose concrete flags only after the comparison.
5. Preserve wasi-libc's separate private-header order when building libc itself.

Do not infer WASI header precedence from Linux musl solely because wasi-libc
contains musl sources. Do not replace exec-compiler resource headers with target
headers. This step does not authorize a new public header API.

## 3. Name the WASI profile constraint accurately

Proposed change in `constraints/wasi/BUILD.bazel`:

- Rename the setting `preview` to `variant`.
- Point the existing constraint values at the renamed setting.
- Preserve `p1`, `p1_threads`, `p2`, and `p3`, their platform labels and triples,
  and the default P1 selection.
- Check references before deciding whether compatibility is needed. Do not add
  an alias without an identified consumer requirement.

Acceptance: implicit/default P1 and each explicit variant resolve as before;
only the setting's name changes. Do not introduce independent version and
threading axes or additional supported combinations.

Keep this public-label change separate from the initial semantic restructuring.

## 4. Preserve complete libc library staging initially

Retain all companion and optional archives in the WASI library search directory.
They are optional at link selection, but are dependencies of directory creation.

This matches existing libc practice: musl stages libc plus companion stubs;
glibc unconditionally generates its support-library collection. Compiler-rt
instead selects optional sanitizer/profile runtimes through explicit settings.

WASI's optional archives contain real code, so their cost may be higher than
empty stubs. Measure action count and build cost before proposing laziness.
Bazel does not derive dependencies from arbitrary `-l...` options: a lazy
design would require a separate explicit selection contract. No such API is
proposed here. Keep CRT ownership separation independent of this decision.

## 5. Keep P2/P3 component support; verify its build contract

Additional tools are required by component output semantics, not evidence of
an architectural or sandboxing defect. Do not split P2/P3 solely because those
tools exist.

Required operations:

| Operation | Execution tools | Target inputs |
| --- | --- | --- |
| Embed command metadata | Pinned `wasm-tools` | Compiled CRT, pinned WIT files |
| Link component | Pinned `wasm-component-ld` and selected LLVM `wasm-ld` | Application objects, CRT, libc, compiler-rt |

Acceptance:

- Tools, WIT, archives, and objects are present in the owning action inputs.
- Every executable matches the execution platform of the action that runs it.
- Clang supplies the declared `wasm-ld` path to the component linker; no host
  `PATH` discovery or undeclared local SDK is required.
- Component outputs have the expected format, imports, and exports.
- P1 does not acquire a dependency on component-only tools through production
  compilation/linking paths.
- Compilation and linking require no WASI execution runtime.

Inspect action graphs and driver invocations, then run focused sandboxed/remote
checks. Source-level `cfg = "exec"` and declared `data` alone do not prove the
complete execution-platform and subprocess contract. Record unsupported or
unexercised execution platforms explicitly.

## 6. Document the exposed support contract

Add a WASI section to the root README and corresponding target-matrix entries:

- wasm32, C, static wasi-libc; C++ standard-library support is outside this PR.
- All platform labels; `wasi_wasm32` defaults to P1.
- Commands by default; `-mexec-model=reactor` selects reactor mode. State which
  variant/mode combinations are demonstrated.
- SDK 34 pin, compiler-version gates, and separately the LLVM versions tested.
- `--@llvm//runtimes/wasi:malloc=dlmalloc|emmalloc|none`: dlmalloc is the default;
  `none` omits the bundled allocator and does not provide a replacement.
- One build example using an existing WASI test target.
- Build-time component tools versus the external runtime needed for execution.

Preserve the following distinction in the evidence table:

| Variant | Existing test coverage |
| --- | --- |
| P1 | Command and reactor execution in wazero |
| P1 threads | Compile/link and structural validation |
| P2/P3 | Component compile/link and structural validation |

The PR reports successful tests using cached LLVM 23.1.2 sources through a
repository override. Those are reported results, not new reproductions by this
review. Existing P2/P3 validation does not establish runtime behavior; allocator
options are not all demonstrated by the current default-path tests.

## Verification and implementation order

1. Agree on step 0's semantic ownership, proposed labels, and public API changes.
2. Record baseline driver/header behavior, action inputs, and focused test results.
3. Implement semantic routing/naming first, preserving behavior. Then separate
   CRT/library inputs and address any proved header or flag-propagation issue in
   distinct changes. Keep the constraint rename and documentation reviewable
   separately. Avoid incidental refactors.
4. Repeat the same reproductions and inspect artifacts/action graphs.
5. Run focused checks with `--config=remote`:
   - `//tests/wasm:wasm_test`
   - `//tests/wasm:wasi_p1_test`
   - `//tests/wasm:wasi_variants_test`
6. Exercise affected compiler-version gates and supported modes, without
   promoting untested combinations to supported claims.
7. Run `bazel build --config=remote //:main` in `e2e/rules_cc` as the normal
   repository feedback check, plus required formatting checks for edited files.
8. Report exact commands, source revisions, action/artifact observations,
   intentional differences, and remaining limitations.

For a demonstrated bug, prove the regression fails before and passes after.
For a structural refactor, demonstrate preserved behavior. No runtime execution
claims may be inferred solely from `wasm-tools validate` or successful linking.

## Semantic-tree review: rationale for step 0

These findings describe the original PR and motivated the initial tree in
step 0. Subsequent review refined libc-header composition and separated thread
model from target features, as recorded in the second checkpoint above.

| Existing WASI integration | Assessment |
| --- | --- |
| `args/wasi:default_libs` includes CRT lookup | Concrete semantic mismatch: `default_startfiles` exists but is empty for WASI. |
| Generic `args:fuse_ld` selects `wasi_components` | Platform/variant routing has entered the generic implementation package instead of the composition/platform hierarchy. |
| `args/wasi:runtime_compile_flags` | Groups thread model, atomics, TLS, C syntax, and a compiler-version compatibility gate under one consumer-oriented name. Concrete variant behavior is flattened into the OS package. |
| `args/wasi:headers` | Ambiguous argument-group name: specifically libc include-search arguments, not all headers or a header artifact. Existing targets elsewhere name that responsibility explicitly. |
| `args/wasi:component_linker` | A sensible concrete linker-choice implementation, but scoped/guarded only as WASI despite its P2/P3 purpose; callers currently supply the narrower restriction. |
| Additional `platform_specific_args` entries | Initially criticized as extending a legacy holder. Review retained hosted-C composition for libc headers because that matches the existing ownership boundary; distinct thread/feature semantics receive named slots. |
| Runtime artifact names such as `c`, `crt1_command`, `library_directory` | A different naming domain from argument groups. Upstream library identities and artifact descriptions are not intrinsically violations of the semantic argument tree. |

The README supports stable semantic slots at composition boundaries, OS-level
routing to variant implementations, and concrete ownership at the applicable
scope. It does not require duplicating identical common implementations into
every variant or nesting execution-platform selection beneath target variants.

Existing code is not fully normalized: the README explicitly identifies legacy
composition holders and temporary Windows duplication. Therefore matching an
older Linux target is evidence of precedent, not sufficient evidence of design
conformance. Conversely, no whole-repository naming migration is requested.

The startup/library split addresses only one issue. Step 0 also addresses
linker-choice routing, the meaning of runtime compile groups, and libc-header
naming without expanding the WASI feature set or normalizing unrelated targets.
