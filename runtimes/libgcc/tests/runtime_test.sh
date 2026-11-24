#!/usr/bin/env bash
# Runs a test binary and checks which unwinder it links. LAUNCHER, if set,
# runs the binary under qemu-user, with the system libraries in QEMU_LD_PREFIX.
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
if [[ -n "${QEMU_LD_PREFIX:-}" ]]; then
  export QEMU_LD_PREFIX="${PWD}/${QEMU_LD_PREFIX}"
fi
run="${LAUNCHER:-${BINARY}}"
"${run}"

"${READELF}" --dynamic "${BINARY}" > "${TEST_TMPDIR}/dynamic.txt"
if grep -F 'libunwind' "${TEST_TMPDIR}/dynamic.txt"; then
  echo "binary depends on LLVM's libunwind" >&2
  exit 1
fi
if [[ "${LINKAGE}" == "dynamic" ]]; then
  grep -F 'Shared library: [libgcc_s.so.1]' "${TEST_TMPDIR}/dynamic.txt"
  # The binary must load the libgcc_s.so.1 in its runfiles, not the system's.
  LD_DEBUG=libs "${run}" > /dev/null 2> "${TEST_TMPDIR}/ld_debug.txt"
  if ! grep -E 'calling init: .*/_solib_[^/]*/libgcc_s\.so\.1$' "${TEST_TMPDIR}/ld_debug.txt"; then
    echo "binary did not load libgcc_s.so.1 from its runfiles" >&2
    grep -F 'libgcc_s' "${TEST_TMPDIR}/ld_debug.txt" >&2 || true
    exit 1
  fi
elif grep -F 'Shared library: [libgcc_s.so.1]' "${TEST_TMPDIR}/dynamic.txt"; then
  echo "static runtime binary depends on libgcc_s.so.1" >&2
  exit 1
fi
