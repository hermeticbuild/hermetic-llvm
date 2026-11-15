#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
archive="${1:?pass the built flang tar.zst archive path}"
archive="$(cd "$(dirname "${archive}")" && pwd)/$(basename "${archive}")"
scratch="$(mktemp -d /tmp/flang-prebuilt-e2e.XXXXXX)"
dist="${scratch}/distribution"
fixture="${scratch}/fixture"
mkdir -p "${dist}" "${fixture}"
tar -xf "${archive}" -C "${dist}"
cp "${repo_root}/e2e/rules_fortran/flang.BUILD.bazel" "${dist}/BUILD.bazel"
: > "${dist}/MODULE.bazel"
cp "${repo_root}/.bazelrc" "${fixture}/.bazelrc"
cp "${repo_root}/e2e/rules_fortran/BUILD.bazel" "${fixture}/BUILD.bazel"
cp "${repo_root}/e2e/rules_fortran/fortran_add.f90" "${fixture}/fortran_add.f90"
cp "${repo_root}/e2e/rules_fortran/c_main.c" "${fixture}/c_main.c"
cp "${repo_root}/prebuilt/flang/smoke.f90" "${fixture}/smoke.f90"
sed -e "s|__LLVM_REPO__|${repo_root}|g" -e "s|__FLANG_DIST__|${dist}|g" \
  "${repo_root}/e2e/rules_fortran/MODULE.bazel.in" > "${fixture}/MODULE.bazel"

echo "e2e fixture: ${fixture}"
cd "${fixture}"
GIT_CONFIG_GLOBAL=/dev/null USE_BAZEL_VERSION=9.3.2 bazel --output_base="${scratch}/bazel-output" test \
  --config=remote \
  --extra_execution_platforms=//:linux_amd64_musl_remote \
  --extra_toolchains=//:flang_toolchain,@llvm//toolchain:all \
  --platforms=@llvm//platforms:linux_amd64_musl \
  //:fortran_main //:c_main --test_output=errors
