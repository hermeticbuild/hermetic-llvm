#!/usr/bin/env bash
# Checks that compiles executing on a Windows host use a param file whatever
# OS they target, since CreateProcessW limits command lines to 32,767
# characters. CI otherwise executes remotely on Linux, so this queries the
# actions with remote execution disabled.
set -euo pipefail

fail() {
  echo >&2 "$@"
  exit 1
}

show_report_context() {
  local file="$1"
  sed -n \
    -e '/Execution platform:/p' \
    -e '/Command Line:/,/)/p' \
    "${file}" | awk 'NR <= 40 { print }' >&2
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
    show_report_context "${file}"
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

case "${1:-${RUNNER_ARCH:-}}" in
  X64 | x64 | x86_64 | AMD64 | amd64)
    exec_archive_cpu="amd64"
    ;;
  ARM64 | arm64 | aarch64)
    exec_archive_cpu="arm64"
    ;;
  *)
    fail "usage: $0 <X64|ARM64>"
    ;;
esac

runner_temp="${RUNNER_TEMP:-/tmp}"
if command -v cygpath >/dev/null 2>&1; then
  runner_temp="$(cygpath -u "${runner_temp}")"
fi
validation_dir="$(mktemp -d "${runner_temp}/windows-native-exec-param-files.XXXXXX")"

# Keep Bazel labels intact under Windows Git Bash.
export MSYS2_ARG_CONV_EXCL="*"

native_flags=(
  --remote_executor=
  --remote_cache=
  --experimental_remote_downloader=
  --repository_cache=
  --repo_contents_cache=
  --spawn_strategy=local
)

echo "Native Windows param file validation: exec=${exec_archive_cpu}, reports=${validation_dir}"

# Keep in sync with LONG_COMMAND_LINE_PLATFORMS in BUILD.bazel.
for platform in linux_x86_64 macos_aarch64 windows_amd64; do
  report="${validation_dir}/${platform}-compile.txt"

  bazel \
    --bazelrc=.bazelrc \
    aquery \
    "${native_flags[@]}" \
    "--platforms=@llvm//platforms:${platform}" \
    --output=text \
    'mnemonic("CppCompile", //:long_command_line)' \
    >"${report}"

  assert_contains "${report}" "Execution platform:"
  assert_absent "${report}" "rbe_platform"
  assert_contains "${report}" "llvm-toolchain-minimal-windows-${exec_archive_cpu}"
  assert_absent "${report}" "llvm-toolchain-minimal-linux-"
  assert_absent "${report}" "llvm-toolchain-minimal-darwin-"
  assert_matches "${report}" 'bin[/\\]clang[+][+][.]exe'
  assert_matches "${report}" '@bazel-out[^ ]*[/\\]long_command_line([.]pic)?[.]o[.]params'
  assert_absent "${report}" "-DPARAM_FILE_PADDING_1000="
done

echo "Native Windows compiles use param files for every target OS."
