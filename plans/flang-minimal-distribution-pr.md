# Minimal Flang distribution PR plan

Status: historical pre-implementation plan. Current scope and future consumer
boundary: [fortran-ruleset-composition.md](fortran-ruleset-composition.md).
The pushed review branch `cerisier/flang-minimal-prebuilts` packages only the
repository-pinned LLVM **23.1.2** Flang compiler for eight host variants. It
adds no private probe, runtime target, retrieval API or Fortran ruleset. The
LLVM 21/22 and 23.1.5 release plan and extra verification lanes below were
superseded by Corentin's later decisions. No PR or release had been created
when this record was updated.

## Superseded proposal (retained as design history)

### Decisions at the time

- Publish one minimal **host compiler** archive per qualified execution-platform variant. The archive contains `bin/flang` (or `bin/flang.exe`), LLVM and Flang license files, and only non-OS host execution dependencies proven necessary by binary inspection. It contains no target libc headers/libraries, CRT, sysroot, Flang-RT, intrinsic `.mod` files, Clang, LLD, archiver, target-specific `flang.cfg`, or helper assets added solely for standalone linking.
- Produce releases for the latest patch in each of LLVM 21, 22 and 23: **21.1.8, 22.1.8, 23.1.5** as of 2026-11-16. Version 23.1.5 exists upstream and in `hermeticbuild/llvm-redist`, but this repository currently indexes and defaults to 23.1.2. Add the exact 23.1.5 source archive metadata; leave the module's default version unchanged in this PR. Never pair a Flang compiler with target modules/runtime from a different LLVM source version.
- Target the same eight host artifact variants as the current LLVM prebuilt workflow: Linux x86_64/arm64 musl, macOS x86_64/arm64, Windows x86_64/arm64 GNU, and Windows x86_64/arm64 MSVC. These are execution-platform variants, not promises about all Fortran output targets. Each variant must pass its host-execution check before its version is released. The first cross-target composition probe remains Linux x86_64 musl.
- Build Flang from each selected LLVM source with the existing source-backed bootstrap transition (`bootstrap_binary(source_backed = True)` or its narrowly adapted equivalent): Stage 1 LLVM compiler, `opt`, ThinLTO, no exceptions/RTTI, release strip policy. Set no Flang FDO profile and no FDO instrumentation. Do not route Flang through Stage 3's LLVM FDO profile. Inspect the actual compile/link actions to prove ThinLTO and absence of profile inputs/flags.
- Artifact form remains `flang-toolchain-<LLVM version>-<host suffix>.tar.zst`, with dedicated `flang-<LLVM version>-r<revision>` releases, SHA256 manifest and artifact attestation. No publication before the PR is approved and merged, followed by a separate explicit release decision.

## Proposed diff

1. Restore the required Flang source trees from the exact selected LLVM source archive. Keep existing exclusions for tests/docs and unrelated subprojects. Patch versioned upstream Bazel overlays only where actual 21/22/23 builds require it; do not carry the prior standalone-archive runtime/sysroot changes into this PR.
2. Add `prebuilt/flang/` packaging rules using the current `mtree`/`tar` pattern. A source-backed, ThinLTO Flang executable and proven host execution files are the only binary inputs. Package licenses. Use `prebuilt/platforms.bzl`'s existing platform matrix and explicit Windows GNU/MSVC variants. Archive contents are explicit, reviewable and version-neutral.
3. Add a Flang release build script and **manual-only** GitHub workflow. The workflow builds all eight variants for the selected LLVM source version, validates archive manifests and host dependencies, computes SHA256, creates attestations and can publish only from a dedicated release ref after merge. No PR or ordinary branch push triggers publication. A version mismatch, reused tag or missing variant fails before publishing.
4. Add LLVM 23.1.5 source metadata to `llvm_versions.json` using the published `llvm-redist` asset digest. Keep ordinary `MODULE.bazel` at its current default; release refs choose exactly 21.1.8, 22.1.8 or 23.1.5, following the LLVM prebuilt branch-version pattern.
5. Add private tests and brief release documentation. No `@llvm//extensions:flang.bzl`, `@flang_prebuilt`, public intrinsic-module/runtime target, Flang toolchain provider, CC mode or build setting in this PR. Those are subsequent API decisions.

## Verification and release gates

- For each of the three versions and eight host variants: build the archive with the release configuration; inspect `tar -tf` against an allowlist; inspect the contained executable's dependency closure (`readelf`, `otool`, or PE imports); run `flang --version` on the matching execution platform; inspect the build action graph for ThinLTO and no Flang FDO. Record exact unsupported cases instead of shipping an unqualified archive.
- For 21.1.8, 22.1.8 and 23.1.5 on the first Linux x86_64-musl target: extract only the minimal archive, compile a Fortran program, generate matching intrinsic modules from source as declared inputs, and link a static executable with target Flang-RT plus the existing Hermetic LLVM CC toolchain through a private `cc_common.link` probe. Inspect compile/link action inputs, output and failure without Flang-RT. This qualifies composition; it does not create a public Fortran ruleset.
- Run focused Bazel checks and the existing `e2e/rules_cc //:main` feedback target; inspect output archives and linked binaries, not only exit codes. The complete matrix is the release gate, including any source-overlay fixes per major.
- After approval and merge, create version-specific release refs from merged main with `MODULE.bazel` set to that ref's LLVM version, build/test there, and dispatch the manual workflow only after an explicit release instruction. Publish three tags, one per version, each with its qualified host archives. Update a future Flang retrieval index only after asset digests exist and its public API has been separately approved.

## PR handoff

Prepare reviewable local commits on a fresh release-only branch based on current main; do not reuse closed PR #954's standalone archive. That branch contains target sysroot/runtime payload and unrelated changes relative to current main. Run review and verification, then push **only the review branch** so GitHub can populate a PR creation form in Chrome. Prefill concise title/body and leave the Create button to Corentin. Do not create the PR or publish any release. If "don't push" also means no remote review branch, stop with local commits; GitHub cannot prepare the PR creation form for an unpushed branch.
