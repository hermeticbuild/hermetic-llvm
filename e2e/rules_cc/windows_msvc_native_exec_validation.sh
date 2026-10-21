#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

show_report_context() {
  local file="$1"
  sed -n \
    -e '/Execution platform:/p' \
    -e '/Environment:/p' \
    -e '/Command Line:/,$p' \
    "${file}" | awk 'NR <= 120 { print }' >&2
}

assert_contains() {
  local file="$1"
  local value="$2"
  if ! grep -Fq -- "${value}" "${file}"; then
    show_report_context "${file}"
    fail "${file} does not contain: ${value}"
  fi
}

assert_absent() {
  local file="$1"
  local value="$2"
  if grep -Fq -- "${value}" "${file}"; then
    fail "${file} unexpectedly contains: ${value}"
  fi
}

assert_matches() {
  local file="$1"
  local pattern="$2"
  if ! grep -Eq -- "${pattern}" "${file}"; then
    show_report_context "${file}"
    fail "${file} does not match: ${pattern}"
  fi
}

assert_hermetic_lib_env() {
  local file="$1"
  if sed -n '/Environment:/p' "${file}" | grep -Fq 'LIB='; then
    assert_contains "${file}" "LIB=__hermetic_llvm_empty_lib__"
  fi
}

case "${1:-${RUNNER_ARCH:-}}" in
  X64 | x64 | x86_64 | AMD64 | amd64)
    exec_cpu="x86_64"
    exec_archive_cpu="amd64"
    other_exec_archive_cpu="arm64"
    ;;
  ARM64 | arm64 | aarch64)
    exec_cpu="aarch64"
    exec_archive_cpu="arm64"
    other_exec_archive_cpu="amd64"
    ;;
  *)
    fail "usage: $0 <X64|ARM64>"
    ;;
esac

runner_temp="${RUNNER_TEMP:-/tmp}"
if command -v cygpath >/dev/null 2>&1; then
  runner_temp="$(cygpath -u "${runner_temp}")"
fi
validation_dir="$(mktemp -d "${runner_temp}/windows-msvc-native-exec.XXXXXX")"

# Reuse the already-fetched external repositories, but discard the regular
# remote-enabled build's outputs and action cache. Subsequent actions must run
# on the native Windows host without duplicating the large LLVM repository.
bazel --bazelrc=.bazelrc clean

native_flags=(
  --remote_executor=
  --remote_cache=
  --experimental_remote_downloader=
  --repository_cache=
  --repo_contents_cache=
  --spawn_strategy=local
  --repo_env=BAZEL_MSVC_RUNTIME_VISUAL_STUDIO_EULA=1
  --repo_env=BAZEL_WINDOWS_SDK_EULA=1
)

run_bazel() {
  local command="$1"
  shift
  bazel \
    --bazelrc=.bazelrc \
    "${command}" \
    "${native_flags[@]}" \
    "$@"
}

echo "Native MSVC execution validation: exec_cpu=${exec_cpu}, reports=${validation_dir}"

for target_cpu in x86_64 aarch64; do
  case "${target_cpu}" in
    x86_64)
      target_triple="x86_64-pc-windows-msvc"
      target_machine="X64"
      ;;
    aarch64)
      target_triple="aarch64-pc-windows-msvc"
      target_machine="ARM64"
      ;;
  esac

  platform="@llvm//platforms:windows_${target_cpu}_msvc"
  compile_report="${validation_dir}/${target_cpu}-compile.txt"
  link_report="${validation_dir}/${target_cpu}-link.txt"

  run_bazel aquery \
    "--platforms=${platform}" \
    --features=-compiler_param_file \
    --output=text \
    'mnemonic("CppCompile", //:windows_msvc_crt_default_probe)' \
    >"${compile_report}"
  run_bazel aquery \
    "--platforms=${platform}" \
    --include_param_files \
    --output=text \
    'mnemonic("CppLink", //:windows_msvc_generated_def_thinlto_binary)' \
    >"${link_report}"

  for report in "${compile_report}" "${link_report}"; do
    assert_contains "${report}" "Execution platform:"
    assert_absent "${report}" "rbe_platform"
    assert_contains "${report}" "llvm-toolchain-minimal-windows-${exec_archive_cpu}"
    assert_absent "${report}" "llvm-toolchain-minimal-windows-${exec_archive_cpu}-msvc"
    assert_absent "${report}" "llvm-toolchain-minimal-windows-${other_exec_archive_cpu}"
    assert_absent "${report}" "llvm-toolchain-minimal-linux-"
    assert_absent "${report}" "llvm-toolchain-minimal-darwin-"
    assert_hermetic_lib_env "${report}"
  done

  assert_matches "${compile_report}" 'bin[/\\]clang-cl[.]exe'
  assert_contains "${compile_report}" "--target=${target_triple}"
  assert_matches "${link_report}" 'bin[/\\]clang-cl[.]exe'
  assert_matches "${link_report}" 'bin[/\\]lld-link[.]exe'
  assert_contains "${link_report}" "/clang:/MACHINE:${target_machine}"
  assert_contains "${link_report}" "/clang:-fuse-ld=lld"

  run_bazel build \
    "--platforms=${platform}" \
    --features=-dynamic_link_msvcrt \
    --features=static_link_msvcrt \
    //:windows_msvc_generated_def_thinlto_binary \
    //:windows_msvc_libcxx_behavior_mt
done

run_bazel test \
  "--platforms=@llvm//platforms:windows_${exec_cpu}_msvc" \
  --features=-dynamic_link_msvcrt \
  --features=static_link_msvcrt \
  //:windows_msvc_libcxx_behavior_mt

echo "Native Windows GNU/MinGW-built clang-cl MSVC execution validation passed."
