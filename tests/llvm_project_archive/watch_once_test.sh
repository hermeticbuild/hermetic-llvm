#!/usr/bin/env bash
# Every rctx.path(label) on a file in the llvm module records its own file
# input, and Bazel checks those one at a time against the repo contents cache.
# The archive rule must watch the patch and overlay tree once instead.
set -euo pipefail

src="$1"

if [[ "$(grep -c 'rctx.watch_tree(' "$src")" != 1 ]]; then
  echo "llvm_project_archive.bzl must call rctx.watch_tree exactly once" >&2
  exit 1
fi

if grep -q 'rctx.read(source)' "$src"; then
  echo "overlay files must be read with watch = \"no\"" >&2
  exit 1
fi

if grep -q 'watch_patch = "no"' "$src"; then
  :
else
  echo "patches must be applied with watch_patch = \"no\"" >&2
  exit 1
fi
