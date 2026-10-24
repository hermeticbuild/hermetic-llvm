#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
logs="$(mktemp -d)"
trap 'rm -rf "$logs"' EXIT
for case in duplicate empty unknown nonroot; do
  case "$case" in
    duplicate) expected='The default Linux headers version may only be configured once' ;;
    empty|unknown) expected='Unknown default Linux headers version:' ;;
    nonroot) expected='Only the root module may configure the default Linux headers version' ;;
  esac
  # Force extension evaluation: an unused extension need not evaluate its tags.
  status=0
  (cd "errors/$case" && "${BAZEL_BIN:-bazel}" "$@" build @kernel_headers//:kernel_headers) >"$logs/$case" 2>&1 || status=$?
  cat "$logs/$case"
  if [[ "$status" -eq 0 ]]; then
    echo "Expected $case configuration to fail" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$logs/$case"; then
    exit 1
  fi
  echo "$case: exit $status: $expected"
done
