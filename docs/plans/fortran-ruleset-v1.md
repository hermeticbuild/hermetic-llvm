# Fortran ruleset v1: proposal for discussion

2026-11-16. **Specification only; no implementation or API approved.**

The proposed ruleset owns Fortran compilation and module dependencies. Hermetic
LLVM owns the C/C++ toolchain and final native link. A Fortran library returns
**both `FortranInfo` and `CcInfo`**: the former describes compiler-readable module
interfaces; the latter describes everything needed to link that library,
including its Fortran runtime. They solve different problems.

The minimal Flang executable archive is an execution tool, not a target SDK.
Intrinsic modules, Flang-RT, target configuration and the C/C++ toolchain must
be supplied separately. Older bundled-archive investigation documents are not
the proposed packaging contract.

## Decisions to agree before implementation

| Decision | Recommended v1 | Alternative and cost |
|---|---|---|
| Rule ownership | Separate ruleset owns providers, toolchain type and rules | LLVM-owned Fortran providers contradict the requested boundary |
| Library providers | `FortranInfo` plus `CcInfo` | `FortranInfo` alone needs adapters for C callers; `CcInfo` alone cannot describe Fortran modules |
| Source granularity | Multiple independent sources per target; cross-file module dependencies use separate targets | One-source-only is simpler but awkward for BLAS/LAPACK; automatic intra-target scheduling needs a source graph/scanner |
| Module outputs | One declared tree artifact per compilation plus a manifest | Explicit module-name attributes allow named outputs but duplicate source declarations and complicate preprocessing |
| Module visibility | Transitive module closure; explicit target dependencies; no strict-deps claim | Enforced direct-use visibility needs compiler/scanner support and must still allow nested module reads |
| Runtime | Target `CcInfo`, automatically propagated by Fortran libraries | Global CC runtime injection contaminates unrelated C/C++ links |
| Native link | `cc_common.link`; archive with `cc_common` | Replaying a flattened CC command loses library semantics and feature ownership |
| Initial qualification | Flang 23.1.2, Linux x86_64 executor, Linux x86_64 musl target, static executable | Other pairs require individual qualification, not an OS-name promise |
| GNU compiler | Compiler-neutral provider structure; Flang implementation first | Shipping GNU support immediately also requires packaging, runtime and ABI qualification |

Names and fields below are proposed **new-ruleset** APIs. Any new or newly
promised **Hermetic LLVM** API remains a separate approval decision. In
particular, target-config retrieval and public intrinsic-module/runtime labels
are not silently settled by this document.

## Ownership and configuration

| Component | Owner | Configuration |
|---|---|---|
| Flang binary and all its execution dependencies | Flang distribution; selected by Fortran ruleset | Execution platform |
| Fortran compiler adapter, toolchain type, providers | Fortran ruleset | Toolchain selected for exec/target pair |
| Target triple, ISA/ABI, libc, deployment target, sysroot | Hermetic LLVM integration | Target platform/configuration |
| Intrinsic modules matching compiler and target | Explicit module-producing/input target | Target contents; generator runs on exec platform |
| Flang-RT and its native dependencies | Explicit runtime target returning `CcInfo` | Target platform/configuration |
| C/C++ objects, compiler builtins, libc, CRT, ordinary linker policy | Selected C/C++ toolchain and ordinary dependencies | Target platform/configuration |
| Fortran objects and user modules | Fortran rules | Target contents; compiler runs on exec platform |

Toolchain registration must constrain both execution and target compatibility.
Repository download selection must use the requested execution platform, never
`repository_ctx.os` as a proxy for a remote executor. Each toolchain distribution
must list supported target backends; a runnable compiler is not proof that its
build contains every LLVM backend.

Both toolchains should resolve in an explicitly coordinated execution group for
the first implementation. With automatic execution groups, actions using the
Fortran compiler must identify that toolchain; archive/link actions must use the
C/C++ toolchain's resolved execution group. Do not combine tools from incompatible
executors by assuming the host platform is the execution platform.

The Fortran compiler's executable/runfiles use `cfg = "exec"`. Its runtime and
intrinsic-module attributes must **not** use an exec transition. Reading a target
runtime through a host-compiler dependency is the wrong configuration boundary.

### Target configuration is a real integration decision

`CcInfo` is not a target-triple provider. Nor does registering a CC toolchain
automatically make its complete C compile command appropriate for Flang.
Hermetic LLVM currently constructs target flags in
`toolchain/args/llvm_target_triple.bzl` and `toolchain/args/BUILD.bazel`; the latter
also adds ISA/ABI details, such as RISC-V flags. These are implementation evidence,
not a newly agreed downstream contract.

For the first qualification fixture, use explicit matching target configuration
in a private adapter and constrain it to the single qualified platform. Before
publishing a reusable integration, choose between:

1. Consuming already-public target/platform metadata through a small adapter
   owned by the Fortran ruleset, after confirming the supported contract.
2. A narrowly scoped, language-neutral target-description API in Hermetic LLVM.
   **This is a proposal requiring explicit approval**, not a dependency of this
   specification that may be implemented automatically.

Do not scrape the C++ link command for a target triple, copy every C/C++ compile
flag into Flang, or infer musl versus glibc from OS/CPU alone. Link settings still
come directly from the selected CC toolchain through `cc_common`.

## Public rules and attributes

Three build rules: `fortran_library`, `fortran_binary`, `fortran_test`. One
registration rule: `fortran_toolchain`. No separate module rule, shared-library
rule, precompiled-module import rule, or Fortran-owned linker in v1.

Common proposed attributes:

| Attribute | Meaning |
|---|---|
| `srcs` | Zero or more independently compiled Fortran sources; generated sources allowed. A source needing a sibling's module must move to a separate target with a `deps` edge |
| `deps` | `attr.label_list(providers = [CcInfo])`; every dependency supplies native link metadata. If it also supplies `FortranInfo`, consume its module metadata too |
| `includes` | Declared textual include files/targets, not arbitrary filesystem directory strings; local to this compilation |
| `include_dirs` | Package-relative directories for those declared files; reject absolute paths and traversal; no dependency propagation in v1 |
| `defines` | Local preprocessor definitions; no transitive propagation |
| `preprocess` | `auto`, `on`, `off`; uppercase Fortran extensions preprocess in `auto`; explicit overrides work for generated/lowercase files |
| `source_form` | `auto`, `free`, `fixed`; extension inference documented; override available |
| `copts` | Local compiler options; cannot override action outputs, module directories, target/ABI, response files, or tool selection |
| `linkopts` | Native-link options, carried in `CcInfo` for libraries and passed to `cc_common.link` for executables |
| `data` | Runtime files and runfiles dependencies; never implicit compile inputs |

Use the normal Bazel `features`, compatibility, visibility and test attributes.
Library adds `alwayslink`, default false. Binary/test add `linkstatic` with
ordinary CC meaning: prefer static user libraries; this does **not** itself mean
a fully static executable. The first musl fixture requests the CC toolchain's
existing fully-static feature. Standard test attributes and explicit `env` apply
to execution, not compilation. Binary and test share compile/link code; test is
a real `test = True` rule, not a shell wrapper around a binary.

For v1, nonempty `defines` with preprocessing disabled is an analysis error.
Fortran `INCLUDE` and preprocessor `#include` are distinct language operations;
both require declared files, and preprocessing behavior remains the compiler's.
Do not run a generic C preprocessor on Fortran text.

Fortran libraries should contain modules/submodules/procedures, not `PROGRAM`.
Binary/test main sources own `PROGRAM`. A `PROGRAM` in a library is unsupported
input in v1; do not add a parser or symbol-scan action solely to enforce that
convention. A duplicate native main may fail at link, but archive extraction can
hide one, so link success does not certify the convention. A dependency-only
binary is possible when its selected dependency owns a native `main`, but the
normal Fortran-main form supplies its program in `srcs`.

Example, including a parent/submodule edge:

```starlark
fortran_library(name = "types", srcs = ["types.f90"])
fortran_library(name = "solver_api", srcs = ["solver_api.f90"], deps = [":types"])
fortran_library(name = "solver_impl", srcs = ["solver_impl.f90"], deps = [":solver_api"])
fortran_library(name = "solver", deps = [":solver_api", ":solver_impl"])
fortran_test(name = "solver_test", srcs = ["test.f90"], deps = [":solver"])
cc_binary(name = "c_app", srcs = ["main.c"], deps = [":solver"])
```

The `solver_impl` source may be `submodule(solver_api) implementation`. The
reverse dependency from API to implementation would create a cycle; the
aggregation target brings both into the link without reversing the module edge.

## Provider contract

Illustrative Starlark, not executable implementation:

```starlark
FortranInfo = provider(fields = {
    "module_compatibility": "opaque compiler/version/target/module-ABI identity",
    "direct_module_dirs": "depset[File] of this target's module trees",
    "transitive_module_dirs": "depset[File] of complete readable module closure",
    "module_manifests": "depset[File] describing logical module names and owners",
    "module_validation": "File or None: successful validation of this module closure",
})

FortranToolchainInfo = provider(fields = {
    "compiler": "FilesToRunProvider, execution configuration",
    "compiler_files": "depset[File], complete execution dependencies",
    "compiler_kind": "adapter identifier; initially flang",
    "compiler_version": "exact supported version/distribution identity",
    "module_compatibility": "opaque module-ABI identity for selected target",
    "target": "ruleset-private normalized target configuration",
    "intrinsic_module_dirs": "declared target module directories",
    "intrinsic_module_files": "depset[File], target contents",
    "runtime_cc_info": "target CcInfo for language runtime and its dependencies",
    "compile_options": "adapter-controlled defaults and compilation-mode options",
    "capabilities": "qualified PIC, preprocessing, target and feature support",
})
```

`FortranInfo` does not carry a second collection of libraries, objects, native
link flags or source files. Native linking uses `CcInfo` exactly once. The
provider's module identity is conservative: compiler family, exact supported
compiler/module version, target/ABI and module-affecting options. Reject mixing
identities at analysis where available. This is not a claim that every patch
release breaks compatibility, nor that matching identity proves ABI correctness.

Initial `copts` must prohibit untracked ABI/module changes such as default-kind
changes; qualified variants belong in the toolchain identity. Optimization and
debug flags do not propagate to dependents. Module files encode an interface;
they are not portable interchange files between Flang and gfortran.

`fortran_library` always returns `CcInfo`, including aggregation-only libraries.
Its linking context includes its own archive, dependency contexts and the
selected runtime when compiling Fortran. A `CcInfo`-only dependency contributes
its complete linking context and ordinary runfiles, but no module paths. Its C
headers/defines do not automatically become Fortran preprocessing inputs: use
the explicit include attributes when appropriate. A dependency carrying both
providers is linked once through `CcInfo`, not once per provider.

An empty aggregator merges dependency linking contexts and Fortran module
closures, adds no archive or runtime of its own, and permits `CcInfo`-only deps.
An entirely empty aggregator has empty providers and no runtime. Its module
compatibility is absent until it receives Fortran module inputs; otherwise a
CC-only aggregator would impose an irrelevant compiler identity. Its CC
compilation context does not
expose `.mod` paths as C/C++ include paths. C declarations for a `bind(c)` interface
belong in an ordinary header-owning `cc_library` wrapper. Preserve dependency
link contexts without exporting unrelated C header metadata from a Fortran node.

Binaries/tests return `DefaultInfo` with executable and runfiles, plus useful
output groups. They do not advertise themselves as reusable native libraries or
module dependencies.

## Module actions and dependency ordering

Fortran `USE` creates a compilation dependency, not merely a link dependency.
The producer must finish before the consumer compiles. The compile action takes
the dependency module trees as **inputs** as well as passing their paths with
`-I`. A command-line search path without its files in action inputs is incomplete.

V1 deliberately has no intra-target source scheduling: a rule can compile many
independent sources in parallel, each against the same dependency module inputs.
This supports a library of hundreds of independent BLAS routines without
hundreds of user-written rule declarations. One source may define several modules
and procedures. Flang processes program units in a single source in dependency
order. When one file needs another file's module, users split those compilation
units into targets and express the graph through `deps`; an empty library groups
the resulting objects/modules. A source requiring an undeclared sibling module
fails compilation on a clean build, regardless of its position in `srcs`.
Never impose correctness by `srcs` order, alphabetical glob order, a shared
writable module directory, or retrying failed compiles until one happens to work.

Alternative source models, in order of increasing complexity:

1. One source per target: simplest contract, but unnecessary target boilerplate
   for large independent-source libraries. Not the recommended public v1 UX.
2. Multiple mutually independent sources: the recommended v1, with dependent
   sources in separate targets. The restriction must appear in attribute docs,
   examples and missing-module troubleshooting.
3. Add source-unit dependency declarations, implemented as separate compile
   actions. Do not overload ordinary label `deps` with an undocumented file DAG.
4. Add a proper preprocess-aware scanner and a declared scheduling mechanism.
   A scanner execution cannot retroactively add arbitrary analysis-phase Bazel
   actions. One action that scans and builds a whole group is possible, with a
   coarser cache/parallelism boundary; it is a different design choice.

### Tree artifact contract

Each source compile action owns a unique module-output tree and object output,
with names derived from a collision-safe source path identity, not basename
alone. The compiler adapter passes `-J <tree>` for Flang. Zero modules must still produce an
empty declared directory. A hermetic compile helper creates it, invokes the
compiler, then writes a declared manifest from actual compiler outputs. Its
implementation language is an implementation decision; no host Python or shell
dependency is assumed by this spec.

The manifest records compiler identity, owner label and source, logical
module/submodule identity and compiler filename. Consumers validate their input manifests and
reject two different producers of the same module identity before invoking the
compiler. Repeated traversal to the same producer in a diamond is deduplicated,
not a conflict. Keep actual module trees as inputs; a manifest is not a substitute.

Each library, including an empty aggregator, also registers a module-namespace
validation action over its complete own-plus-dependency manifest closure. It
produces a success stamp carried in default outputs and the normal validation
output group, so building that library detects conflicting producers without a
downstream compile. Consumers declare their dependencies' validation stamps as
compile inputs. The library also carries its stamp in a
`LinkerInput.additional_inputs` entry in its `CcInfo`, so a C/C++-only consumer
cannot bypass namespace validation by requesting only native linking inputs.
A library's own stamp follows its source compilations; it cannot
be an input of those same actions because that would create a cycle. A CC-only
or completely empty aggregator has no module namespace to validate. Include
standalone conflicting-source and conflicting-aggregator builds in acceptance
tests, not just collisions discovered by a later consumer.

The link pseudocode below omits that validation-only linker input for brevity;
the implementation must merge it into the returned library linking context.

Flang names ordinary modules `<name>.mod` and submodules
`<ancestor>-<submodule>.mod`. `.smod` is **not** a Fortran-standard filename
contract; other compilers have other conventions. The adapter owns filenames and
manifest normalization. Do not derive a module name from its source basename,
assume one module per source, or declare a mandatory `.smod` output for Flang.

Supply the transitive module closure because reading one public interface can
require another module's interface. Source-level `USE` of an indirect dependency
will also be possible in v1; explicitly do not claim enforced strict deps.
Submodules require the ancestor module and, for nested submodules, their parent
submodule outputs. All module trees are immutable inputs to consumers.

Output trees, manifests and search paths must include configuration/target
identity through Bazel's output structure. Compiler actions run with controlled
environment and working directory; suppress default compiler config loading.
Test polluted source/working directories and disabled caches so undeclared host
modules cannot make missing dependency tests pass.

## Compile, archive and link model

1. Resolve the Fortran and C/C++ toolchains and check supported target/ABI pairing.
2. Collect declared source/includes, target intrinsic modules and dependency
   module trees; validate module compatibility.
3. Compile through the compiler adapter with explicit target, source form,
   preprocessing mode, optimization/debug policy, module output and object output.
4. Produce true PIC/non-PIC outputs as required by the selected native-link
   contract. Never label a non-PIC object `pic_objects` merely to make linking pass.
5. Archive via `cc_common.create_linking_context_from_compilation_outputs`, or
   link an executable via `cc_common.link` with dependency linking contexts.
6. Return providers, output groups and correctly merged runfiles.

For initial Linux qualification, compiling all objects as PIC is a viable
explicit policy, with the same genuinely PIC object usable for static linking.
Alternatively build distinct PIC and non-PIC variants. Agree the choice before
implementation. If compiling twice, use distinct module output trees; select one
canonical interface tree and verify equivalence. Two actions cannot own the same
module directory. No ThinLTO, sanitizer or coverage support is implied by ordinary
object support; reject unsupported requested features rather than silently
applying them only at final link.

Conceptual link code:

```starlark
cc_toolchain = find_cc_toolchain(ctx)
features = cc_common.configure_features(
    ctx = ctx,
    cc_toolchain = cc_toolchain,
    requested_features = ctx.features,
    unsupported_features = ctx.disabled_features,
)
objects = cc_common.create_compilation_outputs(
    objects = nonpic_objects,
    pic_objects = pic_objects,
)
contexts = [dep[CcInfo].linking_context for dep in ctx.attr.deps]
if ctx.files.srcs:  # Both libraries and executables that compile Fortran.
    contexts.append(fortran_toolchain.runtime_cc_info.linking_context)

# Library: this API builds the archive and preserves native dependency semantics.
linking_context, linking_outputs = cc_common.create_linking_context_from_compilation_outputs(
    actions = ctx.actions,
    name = ctx.label.name,
    feature_configuration = features,
    cc_toolchain = cc_toolchain,
    compilation_outputs = objects,
    linking_contexts = contexts,
    user_link_flags = ctx.attr.linkopts,
    alwayslink = ctx.attr.alwayslink,
    disallow_dynamic_library = True,
)

# Binary/test: same dependency/runtime contexts; no manual list of archive paths.
result = cc_common.link(
    actions = ctx.actions,
    name = ctx.label.name,
    feature_configuration = features,
    cc_toolchain = cc_toolchain,
    compilation_outputs = objects,
    linking_contexts = contexts,
    user_link_flags = ctx.attr.linkopts,
    output_type = "executable",
    link_deps_statically = ctx.attr.linkstatic,
)
```

These are alternative library/executable paths, not two links for every target.
Empty aggregation libraries merge linking contexts without an empty archive or
adding a runtime. Empty-source binaries rely on dependency contexts; a binary
compiling its own Fortran source adds the toolchain runtime even with no deps.
API keyword support and `rules_cc`/Bazel minimum versions must be pinned and
checked during implementation. `cc_common` owns library ordering/selection,
`alwayslink`, extra linker inputs and response files; consumers must not flatten
`LibraryToLink` into a guessed `.a` list.

### What is explicit and what becomes automatic

The Fortran toolchain explicitly receives the target runtime `CcInfo`. The
Fortran library automatically carries that context onward. Thus a normal
`cc_binary(deps = [":fortran_lib"])` receives Flang-RT even though its main is C.
The user does not repeat runtime dependencies on every rule. The CC toolchain
still owns compiler-rt builtins, libc, CRT and its ordinary C++ runtime policy.
Do not add another bundled builtins archive to the Fortran runtime context just
because an old compiler package included one.

Reuse the runtime target's canonical linking context; do not reconstruct its
`LinkerInput` under each consuming label. A binary may receive that same context
through its libraries and append it for its own source compilation. Bazel's
depset-based context composition is intended to deduplicate shared inputs, but
do not promise exactly one runtime occurrence without inspecting the generated
link action for the pinned Bazel/rules_cc versions. Diamond dependencies and
direct-plus-transitive runtime inclusion are explicit acceptance tests. If that
composition duplicates or misorders the runtime, fix the context construction;
do not flatten and deduplicate archive paths manually.

`cc_common.link` does not inspect object files, infer their source language or
automatically add Flang-RT. Passing the explicit language-runtime context is the
Fortran rule's responsibility. Runtime-native requirements such as math support
belong in that runtime target's linking context, not arbitrary application
`linkopts`. A C/C++-only link must remain unchanged.

For Flang 23.1.2, compilation of a `PROGRAM` emits native `main` and `_QQmain`.
The emitted `main` calls runtime startup, the Fortran body, and runtime termination.
No extra Fortran-main archive/shim is needed for this version. Native CRT startup
still comes from the CC toolchain. A module/procedure source without `PROGRAM`
does not acquire `main`. Older Flang releases may need a separate main component;
if ever supported, attach it only to a Fortran-main link, never every library's
`CcInfo`.

Mixed-language calls should use `bind(c)`/`iso_c_binding` and explicit C
declarations. Ordinary Fortran calling conventions, hidden character lengths,
descriptors and module formats are not generic C ABI. A C main calling Fortran
also does not automatically receive the `PROGRAM`-generated runtime startup;
qualify I/O, command-line/environment behavior and any required initialization
separately. Dynamic-library loading and cross-compiler Fortran ABI are out of v1.

## Existing implementations: reuse ideas, retain ownership boundaries

### miinso/rules_fortran and the actual rules_ml integration

Inspected `miinso/rules_fortran` revision
`f0cac73ebdcbda7bc01b38b8a4ee33869416c220`, also the revision pinned by
`google-ml-infra/rules_ml_toolchain` at
`9ff8598c6dfa182f4fd49f9af761c67bc2e50abd`. The local rules_ml checkout was stale;
the upstream tree, README, module file, adapter and patch were fetched with `gh`.

Reusable: both library providers, compiler-specific options, per-source module
tree outputs, response files, `bind(c)` examples and BLAS/LAPACK fixtures.

Observed code limitations, not claims of reproduced failures:

- A source compiles against dependency module directories only. Sources in one
  rule receive no edges to sibling module outputs. Source order does not fix this.
- Module-directory map keys are source basenames. Distinct producers can
  overwrite entries even when their real module names differ.
- Fortran binary/test manually flatten libraries and flags and run a linker
  executable; `CcInfo` information such as `alwayslink` and additional inputs is
  not preserved as an opaque link graph.
- Library `linkopts` live in `FortranInfo`, not the library's own native linking
  context; C-main consumers do not use that provider to discover them.
- The downloader selects `repository_ctx.os` despite differently named requested
  repositories; execution and target identities need explicit separation.

The rules_ml adapter provides its own compiler/sysroot/runtime integration and
patches the ruleset's toolchain type to an alias owned by rules_ml, removing the
stock registration. Its README asks downstream root modules to copy that patch
and repeat `git_override`. It also extracts CC link arguments/environment and
selects linker tools to feed the existing custom-link implementation. Avoid
requiring this patch/circular ownership model in a new ruleset: let toolchain
producers implement the ruleset-owned type and use `cc_common` for native links.
The adapter's `fortran_main` separation is useful for older LLVM versions; it is
not evidence that LLVM 23 needs a shim. This investigation did not run rules_ml CI.

Sources: [miinso library](https://github.com/miinso/rules_fortran/blob/f0cac73ebdcbda7bc01b38b8a4ee33869416c220/fortran/private/fortran_library.bzl),
[compile](https://github.com/miinso/rules_fortran/blob/f0cac73ebdcbda7bc01b38b8a4ee33869416c220/fortran/private/compile.bzl),
[binary](https://github.com/miinso/rules_fortran/blob/f0cac73ebdcbda7bc01b38b8a4ee33869416c220/fortran/private/fortran_binary.bzl),
[repositories](https://github.com/miinso/rules_fortran/blob/f0cac73ebdcbda7bc01b38b8a4ee33869416c220/fortran/repositories.bzl),
[rules_ml README](https://github.com/google-ml-infra/rules_ml_toolchain/blob/9ff8598c6dfa182f4fd49f9af761c67bc2e50abd/fortran/README.md),
[adapter](https://github.com/google-ml-infra/rules_ml_toolchain/blob/9ff8598c6dfa182f4fd49f9af761c67bc2e50abd/fortran/toolchain.bzl),
[patch](https://github.com/google-ml-infra/rules_ml_toolchain/blob/9ff8598c6dfa182f4fd49f9af761c67bc2e50abd/third_party/rules_fortran/toolchains.patch).

### periareon/rules_fortran

Inspected upstream revision `6154ed120cd938c646cbebe359ff27e6e26490fa` via `gh`.
This implementation already uses `cc_common` for archive/link operations and
has compiler adapters, runfiles, aggregation and implementation-dependency
concepts worth studying. Its default setup discovers host compilers and runtime
search directories; that is a separate mode from a hermetic cross toolchain.
Its compile helper also passes dependency module trees to each source without
sibling edges. The executable path suppresses module output-directory creation,
so a binary source containing modules deserves specific checking. These are
source observations, not a complete review or executed regression suite.

Sources: [common compile/link helper](https://github.com/periareon/rules_fortran/blob/6154ed120cd938c646cbebe359ff27e6e26490fa/fortran/private/common.bzl),
[rules](https://github.com/periareon/rules_fortran/blob/6154ed120cd938c646cbebe359ff27e6e26490fa/fortran/private/fortran.bzl),
[local discovery](https://github.com/periareon/rules_fortran/blob/6154ed120cd938c646cbebe359ff27e6e26490fa/fortran/private/local_config.bzl).

## Evidence and its limits

Authoritative compiler behavior:

- [Flang module documentation](https://flang.llvm.org/docs/ModFiles.html): module
  outputs depend on declarations; single-source program units are processed in
  dependency order; Flang submodule naming uses `.mod`; `-I` searches modules and
  includes, `-J` specifies module output/search, and intrinsic paths are separate.
- [Flang 23.1.2 main generation](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/flang/lib/Optimizer/Builder/Runtime/Main.cpp)
  and [lowering](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/flang/lib/Lower/Bridge.cpp)
  define and invoke native-main generation. The
  [duplicate-main regression](https://github.com/llvm/llvm-project/blob/llvmorg-23.1.2/flang/test/Driver/no-duplicate-main.f90)
  also expects a collision with another native main.
- [GNU directory options](https://gcc.gnu.org/onlinedocs/gfortran/Directory-Options.html)
  demonstrate that `-I`/`-J` concepts can be adapted across compilers, not that
  their module contents or complete flag sets are interchangeable.
- [Bazel cc_common](https://bazel.build/rules/lib/toplevel/cc_common) documents
  the compilation-output and native-link composition APIs used in the proposal.

Fresh local probes on 2026-11-16 used the available third-party Flang **21.1.8**
macOS arm64 executable, not the pending minimal LLVM 23 release. Working files:
`/tmp/fortran-ruleset-spec-probe`. Compiler directory:
`/tmp/flang-ruleset-output/external/rules_fortran++flang+flang_macos_aarch64/bin`.

```sh
flang-new --no-default-config -c main.f90 -o main.o
llvm-nm main.o
# Defined: _main, __QQmain (Mach-O leading underscore).
# Undefined: __FortranAProgramStart, __FortranAProgramEndStatement and I/O calls.

flang-new --no-default-config -J mods -c unrelated_filename.f90 -o parent.o
flang-new --no-default-config -I mods -J submods -c child.f90 -o child.o
ls mods submods
# mods: parent.mod, second.mod
# submods: parent-child.mod
llvm-nm parent.o child.o
# No main in either; child defines __QMparentPwork.
```

`main.f90` is a program printing hello. `unrelated_filename.f90` defines modules
`parent` and `second`; `parent` declares an interface for module subroutine
`work`. `child.f90` defines `submodule(parent) child` and implements `work`.
The same compiler rejected `--target=x86_64-unknown-linux-musl` with “No available
targets are compatible”; this distribution lacks the requested backend.

Earlier LLVM 23.1.2 Linux-musl `cc_common.link` probes are documented in
`hermetic-llvm-flang-investigation/plans/flang-prebuilt.md` and retained under
`/tmp/flang-cc-common-probe`. Their source rule was inspected in this turn.
Fresh symbol inspection of its retained `bazel-bin/fortran_main` found `main`,
`_QQmain`, `_FortranAProgramStart`. This confirms that artifact's composition;
it is **not** a new remote build or validation of the proposed ruleset. The old
scratch rule lists one object in both PIC/non-PIC slots; production must obey
the actual PIC contract instead. Prior positive/negative runtime-link tests
remain prior evidence, not newly rerun results.

## Acceptance tests and release boundary

Tests should verify observable artifacts and action inputs, not only successful
commands. Record baseline failures for fixes to existing implementations; a new
ruleset instead needs positive and negative contract tests from its first slice.

| Area | Required scenarios |
|---|---|
| Native entry | Fortran `PROGRAM` defines main and links/runs through CC toolchain; module-only source has no main; duplicate-main negative fixture; document unsupported library PROGRAM |
| Runtime propagation | C main calls `bind(c)` Fortran using runtime operations; nested/diamond deps; omission of runtime fails a private negative fixture; pure C link has no Flang-RT |
| Modules | Filename differs from module; zero/two modules; direct/transitive use; duplicate producers rejected when building the library or aggregator alone; repeated same producer allowed; absent dependency fails |
| Submodules | Ancestor and nested parent dependencies; output naming matches adapter; no `.smod` assumption |
| Source model | Many independent sources compile in parallel; sibling USE fails without target edge; split-target form passes; same-source multiple modules work; duplicate basenames stay distinct; empty aggregator preserves dependencies without adding runtime |
| Preprocessing | `.F90` auto; lowercase forced on; explicit off; conditional modules; declared include invalidation; missing include fails |
| Native link semantics | `alwayslink`/BLOCK DATA case, transitive linkopts, additional linker inputs, C++ dependency, runtime deduplication/order |
| Configuration | dbg/opt; target mismatch rejected; compiler/module mismatch rejected; actual PIC object evidence; unsupported ThinLTO/coverage/sanitizers rejected |
| Hermeticity | Sandboxed and remote actions; polluted host module dirs; no default config; no host PATH linker/SDK; compiler/tool/runfiles inputs complete |
| Changes and cache | Source/include/module change causes correct consumer rebuild; clean and incremental builds agree; unrelated library remains cached |
| Cross | Inspect object/executable architecture and ABI; run on matching target runner or explicitly qualified emulator; analysis alone is insufficient |
| Runfiles/test | Data access under `bazel test`; expected nonzero failure; args/environment; no dependence on workspace cwd |

Initial release excludes Windows, Darwin, shared Fortran runtime, shared-library
production, GNU Fortran, OpenMP/offload, MPI/coarrays, quadmath extensions,
cross-compiler modules, ThinLTO, sanitizers and coverage until independently
qualified. This does not assert that those features cannot work.

Windows adds COFF/import libraries and Flang's emitted dependent-library
directives; these must agree with CRT/runtime selection. Darwin adds deployment
target, SDK and shared-library/runpath behavior. GNU adds packaged compiler
subprograms, libgfortran and possibly other runtime dependencies; copying Flang
archive names is not a GNU implementation. Native-module artifacts must stay
paired with their compiler/target on every platform.

## Adoption phases

1. Agree provider ownership, source granularity, module-tree policy, runtime
   propagation, PIC policy and the exact Hermetic LLVM retrieval contract.
2. Build a private single-pair fixture using the minimal host compiler, declared
   intrinsic modules, explicit target runtime and existing CC toolchain. Pass
   Fortran-main and C-main runtime tests plus module/submodule negative cases.
3. Extract the three rules and ruleset-owned toolchain type. Publish only the
   qualified pair; pin supported Bazel/rules_cc/compiler versions. Register
   external compiler toolchains without patching rule ownership.
4. Add real BLAS/LAPACK consumers and measure target count, cache invalidation and
   build parallelism before deciding whether multi-source scheduling is needed.
5. Extend one platform/compiler/feature at a time with object/link/run evidence.

Paste-ready motivation for a future implementation PR:

> Fortran modules need declared compile-time dependencies, while mixed-language
> consumers need the complete native link graph. Add a Fortran ruleset that
> exports module metadata through `FortranInfo` and runtime-aware native
> dependencies through `CcInfo`, so Hermetic LLVM's existing C/C++ toolchain owns
> the final link for both Fortran and C/C++ entry points.
