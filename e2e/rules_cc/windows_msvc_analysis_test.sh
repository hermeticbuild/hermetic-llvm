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

for cpu in x86_64 aarch64; do
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:linux_${cpu}_to_windows_${cpu}_msvc" \
    >/dev/null
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:stage1_linux_${cpu}_to_windows_${cpu}_msvc" \
    >/dev/null
  bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:windows_${cpu}_to_windows_${cpu}" \
    >/dev/null
  if bazel --bazelrc=.bazelrc query \
    "@llvm//toolchain:windows_${cpu}_to_windows_${cpu}_msvc" \
    >/dev/null 2>&1; then
    echo >&2 "native Windows MSVC target toolchain unexpectedly registered for ${cpu}"
    exit 1
  fi
  for stage in stage2 stage3; do
    bazel --bazelrc=.bazelrc query \
      "@llvm//toolchain:${stage}_linux_${cpu}_to_windows_${cpu}_msvc" \
      >/dev/null
  done
done

expect_failure \
  windows-msvc-libstdcxx \
  "Layer 1 MSVC ABI requires //constraints/cxxstdlib:libcxx" \
  "${common_flags[@]}" \
  --platforms=//:windows_x86_64_msvc_libstdcxx_invalid \
  //:windows_msvc_crt_default_probe

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

for platform in windows_x86_64_msvc windows_aarch64_msvc; do
  bazel --bazelrc=.bazelrc build \
    "${common_flags[@]}" \
    --nobuild \
    --platforms="@llvm//platforms:${platform}" \
    //:windows_msvc_parse_headers_c \
    //:windows_msvc_parse_headers_cpp
done

expect_failure \
  windows-msvc-c-header-defaults-to-cxx \
  "error: expected ')'" \
  "${common_flags[@]}" \
  --features=-parse_headers_as_c \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  //:windows_msvc_parse_headers_c

expect_failure \
  windows-msvc-dynamic-libcxx \
  "is incompatible" \
  "${common_flags[@]}" \
  --platforms=@llvm//platforms:windows_x86_64_msvc \
  @llvm-project//libcxx:libcxx.shared
