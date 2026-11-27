#!/usr/bin/env bash
set -euo pipefail

expect_failure() {
  local name="$1"
  local expected="$2"
  shift 2
  local output="${RUNNER_TEMP:-/tmp}/${name}.log"
  if bazel --bazelrc=.bazelrc build "$@" >"${output}" 2>&1; then
    echo >&2 "${name} unexpectedly succeeded"
    exit 1
  fi
  if ! grep -Fq -- "${expected}" "${output}"; then
    echo >&2 "${name} did not report: ${expected}"
    sed -n '1,160p' "${output}" >&2
    exit 1
  fi
}

common_flags=(
  "$@"
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)

unexpected_bootstrap_toolchains="$(bazel --bazelrc=.bazelrc query \
  'filter(":stage[123]_", @llvm//toolchain:all + @llvm_toolchains//:all)')"
if [[ -n "${unexpected_bootstrap_toolchains}" ]]; then
  echo >&2 "bootstrap toolchains unexpectedly declared alongside the default toolchains"
  echo >&2 "${unexpected_bootstrap_toolchains}"
  exit 1
fi

for cpu in x86_64 aarch64; do
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:linux_${cpu}_to_windows_${cpu}_msvc" \
    >/dev/null
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:windows_${cpu}_to_windows_${cpu}" \
    >/dev/null
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:windows_${cpu}_to_windows_${cpu}_msvc" \
    >/dev/null
  for stage in stage1 stage2 stage3; do
    bazel --bazelrc=.bazelrc query \
      "@llvm//toolchain/bootstrap:${stage}_linux_${cpu}_to_windows_${cpu}_msvc + @llvm_toolchains//bootstrap:${stage}_linux_${cpu}_to_windows_${cpu}_msvc" \
      >/dev/null
  done
done

expect_failure \
  windows-msvc-libstdcxx \
  "MSVC ABI requires //constraints/cxxstdlib:libcxx or //constraints/cxxstdlib:msvcstl" \
  "${common_flags[@]}" \
  --platforms=//:windows_x86_64_msvc_libstdcxx_invalid \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-mingw-msvcstl \
  "//constraints/cxxstdlib:msvcstl requires a Windows MSVC target" \
  "${common_flags[@]}" \
  --platforms=//:windows_x86_64_mingw_msvcstl_invalid \
  //:main_default

expect_failure \
  windows-msvc-missing-crt \
  "MSVC ABI requires exactly one retail CRT mode" \
  "${common_flags[@]}" \
  --features=-dynamic_link_msvcrt \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-conflicting-crt \
  "is provided by all of the following features: dynamic_link_msvcrt static_link_msvcrt" \
  "${common_flags[@]}" \
  --features=static_link_msvcrt \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-unsupported-feature \
  "is provided by all of the following features: msvc_supported_configuration asan" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_unsupported_feature_probe

expect_failure \
  windows-msvc-fdo-optimize \
  "is provided by all of the following features: msvc_supported_configuration fdo_optimize" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_fdo_optimize_probe

bazel --bazelrc=.bazelrc build \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_generated_def_thinlto_binary

expect_failure \
  windows-msvc-header-parsing \
  "MSVC ABI Layer 1 does not support feature(s): parse_headers" \
  "${common_flags[@]}" \
  --features=-layering_check \
  --features=parse_headers \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_crt_default_probe

expect_failure \
  windows-msvc-dynamic-libcxx \
  "is incompatible" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  @llvm-project//libcxx:libcxx.shared
