# Flang prebuilt implementation evidence

2026-11-15. Branch: `cerisier/flang-prebuilt-implementation`. Source: LLVM 23.1.2. The first-platform artifact and manual release workflow are implemented; no artifact has been published and no public extension API has been added.

## Qualified contract

Linux x86_64 execution to Linux x86_64 musl static executables. The archive is relocatable and carries Flang, its intrinsic modules and runtime, compiler-rt builtins, LLVM's multicall tools including LLD, the matching musl sysroot/CRT, and LLVM/Flang/musl license files. `bin/flang.cfg` selects those bundled paths. Dynamic linking, cross targets, macOS, Windows, OpenMP, CUDA and quadmath are not qualified by these tests.

The archive target is constrained to Linux x86_64 musl. An explicit build under `//platforms:linux_amd64_gnu.2.28` fails analysis as incompatible, preventing a mixed-target package; Linux musl analysis succeeds with the matching musl execution platform.

The selected final-link owner depends on the ruleset rule: `fortran_test` invokes Flang; `cc_test` consuming `fortran_library` invokes the registered Hermetic LLVM `CppLink` toolchain. The ruleset fixture enables `fully_static_link` for the latter.

## Reproduction and verification

The baseline source extraction omitted `flang` and `flang-rt`; the restored-source diagnostic and its visibility, C++ runtime symbol, and musl backtrace failures are recorded in [the investigation](flang-prebuilt.md). Those failures motivated source extraction and upstream overlay fixes before packaging.

After the changes:

```sh
bazel --output_base=/tmp/flang-implementation-output test --config=remote \
  --extra_execution_platforms=@rbe_platform//:rbe_linux_x86_64_musl \
  --platforms=//platforms:linux_amd64_musl \
  //prebuilt/flang:linux_amd64_musl_smoke --test_output=errors
```

Passed: [remote invocation](https://app.buildbuddy.io/invocation/a07f17d9-fd65-4887-8fc7-cc3cf94f9782). The test extracts the archive under a path containing spaces, moves it, invokes Flang with a cleared environment and unavailable host-tool `PATH`, checks its `-###` link trace, compiles and runs an ISO/IEEE module program, and checks `llvm-readelf` reports no ELF interpreter or `NEEDED` entries. Removing a bundled module, LLD, or the Flang runtime independently makes the corresponding compile/link fail. The archive was about 159 MiB with zstd level 6.

The source-built Flang executable and musl runtime archive also built separately. The former is a static ELF with no interpreter; the latter has no `__libcpp_verbose_abort` undefined symbol after forcing `stl-overrides.h`. The generated musl config disables the unavailable backtrace header.

`--config=release` initially produced LLVM bitcode members in the runtime archive because that config enables ThinLTO globally. Disabling ThinLTO on the Flang runtime target changes its packaged members to ELF relocatable objects. The optimized archive rebuild and relocated smoke test passed: [release invocation](https://app.buildbuddy.io/invocation/2663a5ce-8718-4301-a1d5-184174749944). `llvm ar x` plus `file *.o` found no bitcode members in the final archive.

```sh
e2e/rules_fortran/verify.sh \
  /tmp/flang-implementation-output/execroot/_main/bazel-out/linux_amd64_musl-fastbuild/bin/prebuilt/flang/linux_amd64_musl_release.tar.zst
```

The pinned `miinso/rules_fortran` 0.1.0 fixture passed Fortran-main and C-main `bind(c)` tests under remote Linux musl execution: [optimized archive ruleset invocation](https://app.buildbuddy.io/invocation/8770d67c-44e9-4a69-86d2-333a588d7227). `aquery` showed `FortranLinkTest` executes the packaged `bin/flang`, while `CppLink` executes Hermetic LLVM's `bin/clang++` with `libflang_rt.runtime.a` and builtins as inputs. Both downloaded fastbuild executables had no `INTERP` or `NEEDED` entries per `llvm readelf -l -d`; the optimized archive's standalone smoke test repeated the static executable check.

The fixture uses an explicit private toolchain declaration because the ruleset's stock downloader selects the host OS, even for a requested Linux repository on a macOS host. This test does not change that upstream rule.

The release staging script was run locally with `FLANG_RELEASE_TAG=flang-23.1.2-r1`, `FLANG_RELEASE_DIR=/tmp/flang-release-staging-23.1.2-r1-recheck` and `FLANG_BAZEL_OUTPUT_BASE=/tmp/flang-implementation-output`. It reran the release-mode archive smoke test and both ruleset tests with uncached test results ([ruleset invocation](https://app.buildbuddy.io/invocation/af56d5f0-80b9-4230-9c05-2f639e753b62)); the staged `flang-toolchain-23.1.2-linux-amd64-musl.tar.zst` was 98 MiB and `shasum -a 256 -c SHA256.txt` passed. A mismatched version tag and an existing staging destination both fail before any build. No GitHub publication step ran.

## Remaining before publication

- Review and merge this branch. The `flang-prebuilt.yml` workflow has only a manual trigger, requires `main`, and rejects an existing tag before entering the release environment. Its staging script runs the release-mode relocated archive smoke test and pinned ruleset fixture before preparing `flang-toolchain-<version>-linux-amd64-musl.tar.zst` and `SHA256.txt`; the workflow then attests and publishes them.
- Dispatch the workflow from merged `main` with a new `flang-<version>-r<revision>` tag only when a release is intended. This session did not dispatch it or create a GitHub release.
- Add each additional execution/target pair only with its own sysroot, runtime configuration, final-link trace, relocated-archive test and ruleset consumption test. The current archive makes no claim for those pairs.
