#!/usr/bin/env bash
# Asserts which C++ exception-runtime symbols a statically linked binary
# defines. Mode "absent": none of them may be defined (libc++abi built from
# cxa_noexception.cpp). Mode "present": __cxa_throw must be defined (the
# default runtimes, where operator new throws std::bad_alloc).
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <llvm-nm> <binary> absent|present" >&2
  exit 2
fi

nm=$1
binary=$2
mode=$3

if [[ ! -x "$nm" ]]; then
  echo "FAIL: nm $nm is not executable" >&2
  exit 1
fi

if [[ ! -e "$binary" ]]; then
  echo "FAIL: $binary does not exist" >&2
  exit 1
fi

symbols=$("$nm" --defined-only "$binary")
eh_symbols=$(grep -E ' (__cxa_throw|__cxa_begin_catch|__gxx_personality_v0)$' <<<"$symbols" || true)

case "$mode" in
absent)
  if [[ -n "$eh_symbols" ]]; then
    echo "FAIL: $binary defines exception-runtime symbols with @llvm//runtimes:exceptions=False:" >&2
    echo "$eh_symbols" >&2
    exit 1
  fi
  echo "OK: $binary defines no exception-runtime symbols"
  ;;
present)
  if ! grep -qE ' __cxa_throw$' <<<"$eh_symbols"; then
    echo "FAIL: $binary does not define __cxa_throw with the default runtimes; the control is broken" >&2
    echo "$symbols" | grep -E 'cxa|personality' >&2 || true
    exit 1
  fi
  echo "OK: $binary defines __cxa_throw with the default runtimes"
  ;;
*)
  echo "usage: $0 <llvm-nm> <binary> absent|present" >&2
  exit 2
  ;;
esac
