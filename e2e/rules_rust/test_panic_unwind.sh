#!/usr/bin/env bash
# Runs BINARY, a program that catches a Rust panic and prints "caught", and
# checks that the Rust code in RUST_OUTPUT unwinds with libgcc rather than
# LLVM's libunwind: with libgcc_eh.a linked in for LINKAGE=static, and with
# libgcc_s.so.1 for LINKAGE=dynamic.
set -euo pipefail

fail() {
  echo "$*" >&2
  exit 1
}

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
output="$("${BINARY}")"
[[ "${output}" == "caught" ]] || fail "${BINARY} printed '${output}'"

"${READELF}" --dynamic "${RUST_OUTPUT}" > "${TEST_TMPDIR}/dynamic.txt"
if grep -F 'libunwind' "${TEST_TMPDIR}/dynamic.txt"; then
  fail "${RUST_OUTPUT} depends on LLVM's libunwind"
fi
if [[ "${LINKAGE}" == "static" ]]; then
  # LLVM's libunwind defines __unw_* functions, and libgcc's unwinder
  # uw_frame_state_for.
  "${READELF}" --symbols "${RUST_OUTPUT}" > "${TEST_TMPDIR}/symbols.txt"
  if grep -E ' __unw_' "${TEST_TMPDIR}/symbols.txt"; then
    fail "${RUST_OUTPUT} links LLVM's libunwind"
  fi
  grep -qE ' uw_frame_state_for$' "${TEST_TMPDIR}/symbols.txt" ||
    fail "${RUST_OUTPUT} does not link libgcc's unwinder"
else
  grep -F 'Shared library: [libgcc_s.so.1]' "${TEST_TMPDIR}/dynamic.txt" ||
    fail "${RUST_OUTPUT} does not depend on libgcc_s.so.1"
  "${READELF}" --dyn-syms "${RUST_OUTPUT}" > "${TEST_TMPDIR}/dyn_syms.txt"
  grep -E ' UND _Unwind_RaiseException@GCC_3\.0' "${TEST_TMPDIR}/dyn_syms.txt" ||
    fail "${RUST_OUTPUT} does not take _Unwind_RaiseException from libgcc_s.so.1"
fi
