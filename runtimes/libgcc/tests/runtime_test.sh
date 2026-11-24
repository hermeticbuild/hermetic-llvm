#!/usr/bin/env bash
# Runs a test binary and checks which unwinder it links.
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
"${BINARY}"

"${READELF}" --dynamic "${BINARY}" > "${TEST_TMPDIR}/dynamic.txt"
if grep -F 'libunwind' "${TEST_TMPDIR}/dynamic.txt"; then
  echo "binary depends on LLVM's libunwind" >&2
  exit 1
fi
if [[ "${LINKAGE}" == "dynamic" ]]; then
  grep -F 'Shared library: [libgcc_s.so.1]' "${TEST_TMPDIR}/dynamic.txt"
elif grep -F 'Shared library: [libgcc_s.so.1]' "${TEST_TMPDIR}/dynamic.txt"; then
  echo "static runtime binary depends on libgcc_s.so.1" >&2
  exit 1
fi
