#!/usr/bin/env bash

set -euo pipefail

llvm_nm="$1"
binary="$2"

# The C functions are aliases of functions in LLVM libc's namespace.
for function in memcmp bcmp strlen; do
  if ! "$llvm_nm" "$binary" | grep -q "__llvm_libc_musl[0-9]*${#function}${function}E"; then
    echo "$binary doesn't contain LLVM libc's $function" >&2
    exit 1
  fi
done
