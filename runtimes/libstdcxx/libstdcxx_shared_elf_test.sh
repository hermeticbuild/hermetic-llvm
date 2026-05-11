#!/usr/bin/env bash

set -euo pipefail

shared="${LIBSTDCXX_SHARED:?}"
real="${LIBSTDCXX_SHARED_REAL:?}"
soname="${LIBSTDCXX_SHARED_SONAME:?}"
linker_name="${LIBSTDCXX_SHARED_LINKER_NAME:?}"

dynamic="${TEST_TMPDIR}/dynamic.txt"
versions="${TEST_TMPDIR}/versions.txt"

readelf -d "${shared}" > "${dynamic}"
grep -F "Library soname: [libstdc++.so.6]" "${dynamic}" >/dev/null

readelf --version-info "${shared}" > "${versions}"
grep -F "Version definition section '.gnu.version_d'" "${versions}" >/dev/null
grep -F "Name: GLIBCXX_3.4" "${versions}" >/dev/null
grep -F "Name: GLIBCXX_3.4.35" "${versions}" >/dev/null
grep -F "Name: CXXABI_1.3" "${versions}" >/dev/null

readelf -h "${real}" >/dev/null
test -L "${soname}"
test -L "${linker_name}"
