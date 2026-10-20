#!/usr/bin/env bash
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
[[ "$("${BINARY}")" == "42" ]]

"${READELF}" --dynamic "${BINARY}" > "${TEST_TMPDIR}/dynamic.txt"
if [[ "${LINKAGE}" == "static" ]]; then
  if grep -F 'Shared library: [libstdc++.so.6]' "${TEST_TMPDIR}/dynamic.txt"; then
    echo "static runtime target unexpectedly depends on shared libstdc++" >&2
    exit 1
  fi
else
  grep -F 'Shared library: [libstdc++.so.6]' "${TEST_TMPDIR}/dynamic.txt"
  "${READELF}" --version-info "${BINARY}" > "${TEST_TMPDIR}/versions.txt"
  grep -F 'Name: GLIBCXX_' "${TEST_TMPDIR}/versions.txt"
  grep -F 'Name: CXXABI_' "${TEST_TMPDIR}/versions.txt"
fi
