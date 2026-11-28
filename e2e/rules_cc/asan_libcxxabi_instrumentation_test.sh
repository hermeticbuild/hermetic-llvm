#!/usr/bin/env bash
set -euo pipefail

# __cxa_throw calls this hook only when libc++abi is built with ASan.
"$NM" --print-file-name --undefined-only "$STATIC" |
  grep -E 'cxa_exception(\.pic)?\.o:.* __asan_handle_no_return$'
"$NM" --dynamic --undefined-only "$SHARED" |
  grep -E ' __asan_handle_no_return$'
