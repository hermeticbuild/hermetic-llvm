#!/usr/bin/env bash
set -euo pipefail
symbols="$("$2" --defined-only "$1")"
grep -Eq ' [TW] unw_getcontext$' <<< "$symbols"
grep -Eq ' [TW] unw_step$' <<< "$symbols"
if grep -Eq ' [TW] _Unwind_' <<< "$symbols"; then
  echo "stack-walking archive must not define exception-unwinder symbols" >&2
  exit 1
fi
