# Header search order checks

The compile fixtures check real headers and `#include_next` behavior. The
`search_*_test` targets compare Clang's **effective** `-E -v` search list with
ordered goldens of version-independent directory roles. Each configured
target has a C and C++ check because Clang inserts C++ library roots only for
C++ actions.

The private aspect in `search.bzl` reads the native `cc_library` compile
action's expanded `argv`. Its companion action shadows that compile action's
inputs and environment. `search_capture.sh` removes only compilation and
output-file options, runs the same compiler with preprocessing and verbose
output enabled, and maps recognized directory identities to roles. Each golden
includes Clang's quote and angle search blocks, with their boundaries, Bazel's
package and generated quote roots, and every target and toolchain header root.
An unknown directory, missing search block, or changed role order fails the
test. Bazel 8 omits a generated LLVM root present with Bazel 9 and later in
several configurations. Those configurations use separate full-list goldens
selected using `bazel_features.cc.supports_starlarkified_toolchains`.
The captured stderr and preprocessed source are available through the
`search_debug` output group. This is a replay of the native action's logical
arguments; Bazel may execute the original action through a parameter file or
path mapping, so it is not a byte-for-byte replay of that spawn.

The expected **category** order follows LLVM Clang main at
[`5b790bf6899ecb40b16983d288969fbee422163e`](https://github.com/llvm/llvm-project/commit/5b790bf6899ecb40b16983d288969fbee422163e),
checked on 2026-11-16. This repository selects LLVM 23.1.2. Relevant driver
implementations are [common preprocessing](https://github.com/llvm/llvm-project/blob/5b790bf6899ecb40b16983d288969fbee422163e/clang/lib/Driver/ToolChains/Clang.cpp#L1150),
[Linux](https://github.com/llvm/llvm-project/blob/5b790bf6899ecb40b16983d288969fbee422163e/clang/lib/Driver/ToolChains/Linux.cpp#L784),
[MinGW](https://github.com/llvm/llvm-project/blob/5b790bf6899ecb40b16983d288969fbee422163e/clang/lib/Driver/ToolChains/MinGW.cpp#L724),
[MSVC](https://github.com/llvm/llvm-project/blob/5b790bf6899ecb40b16983d288969fbee422163e/clang/lib/Driver/ToolChains/MSVC.cpp#L812), and
[Darwin](https://github.com/llvm/llvm-project/blob/5b790bf6899ecb40b16983d288969fbee422163e/clang/lib/Driver/ToolChains/Darwin.cpp#L2954).
The order *within* a category comes from this repository's component choices
in `toolchain/args/BUILD.bazel`, `toolchain/args/linux/BUILD.bazel`, and
`toolchain/args/windows/{mingw,msvc}/BUILD.bazel`.

The active suite captures one representative target for each search behavior:
GNU, MinGW, MSVC with libc++, Darwin, BPF, and WebAssembly, plus GNU with
libstdc++, MSVC with Microsoft STL, CUDA host preprocessing, and the MSVC
external-include category. BPF and WebAssembly use different Clang toolchains
even though their expected lists match. C and C++ use separate goldens where
their lists differ. The compile fixtures still cover every supported GNU,
MinGW, MSVC, and Darwin CPU, so architecture-specific headers and
`#include_next` chains are checked. The CUDA case checks host preprocessing
and does not claim device compilation.

Musl's C-before-builtin placement is intentional, but its current `-isystem`
C components appear **before** target system includes. The two
`musl_search_tests` compare against the desired user-first order and are
marked `manual`; they currently fail for that known defect. Remove the manual
exclusion and include them in `search_tests` after the musl ordering fix.
WASI and UEFI are outside this matrix.
