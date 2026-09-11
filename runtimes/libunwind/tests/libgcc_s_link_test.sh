#!/usr/bin/env bash

# Checks that a binary linked with --@llvm//config:experimental_use_llvm_libgcc
# depends on libgcc_s.so.1 rather than libunwind.so.1, and optionally runs it.

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 <readelf> <binary> [run]" >&2
  exit 2
fi

readelf="$1"
binary="$2"
run="${3:-}"

if [[ ! -x "$readelf" ]]; then
  echo "FAIL: readelf $readelf is not executable" >&2
  exit 1
fi

dynamic="$("$readelf" -d "$binary")"
if ! grep -qF "Shared library: [libgcc_s.so.1]" <<<"$dynamic"; then
  echo "FAIL: $binary does not depend on libgcc_s.so.1" >&2
  echo "$dynamic" >&2
  exit 1
fi
if grep -qF "Shared library: [libunwind.so.1]" <<<"$dynamic"; then
  echo "FAIL: $binary still depends on libunwind.so.1" >&2
  echo "$dynamic" >&2
  exit 1
fi

if [[ "$run" == "run" ]]; then
  output="$("$binary")"
  [[ "$output" == "exception caught" ]]
fi

echo "OK: $binary depends on libgcc_s.so.1"
