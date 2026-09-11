#!/usr/bin/env bash

# Checks that a shared object built with --@llvm//config:experimental_use_llvm_libgcc
# gets its unwinder from libgcc_s.so.1 rather than carrying one of its own:
# it depends on libgcc_s.so.1, not on libunwind.so.1, and defines no _Unwind_*
# symbol itself.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <readelf> <shared-object>" >&2
  exit 2
fi

readelf="$1"
shared="$2"

if [[ ! -x "$readelf" ]]; then
  echo "FAIL: readelf $readelf is not executable" >&2
  exit 1
fi

dynamic="$("$readelf" -d "$shared")"
if ! grep -qF "Shared library: [libgcc_s.so.1]" <<<"$dynamic"; then
  echo "FAIL: $shared does not depend on libgcc_s.so.1" >&2
  echo "$dynamic" >&2
  exit 1
fi
if grep -qF "Shared library: [libunwind.so.1]" <<<"$dynamic"; then
  echo "FAIL: $shared still depends on libunwind.so.1" >&2
  exit 1
fi

defined_unwinder="$("$readelf" --dyn-syms "$shared" | awk '$4 == "FUNC" && $7 != "UND" && $8 ~ /^_Unwind_/ { print $8 }')"
if [[ -n "$defined_unwinder" ]]; then
  echo "FAIL: $shared carries its own unwinder:" >&2
  echo "$defined_unwinder" >&2
  exit 1
fi

echo "OK: $shared depends on libgcc_s.so.1 for unwinding"
