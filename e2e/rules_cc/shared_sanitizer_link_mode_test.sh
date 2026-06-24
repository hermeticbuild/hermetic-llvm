#!/usr/bin/env bash
set -euo pipefail

# Verifies --@llvm//config:shared_sanitizer flips the link mode: the static
# build must not have a sanitizer-runtime DT_NEEDED, the shared build must.
#
# Env (set by the BUILD target):
#   STATIC_BIN - rlocationpath of the binary built with the static sanitizer macro
#   SHARED_BIN - rlocationpath of the binary built with the shared sanitizer macro
#   READELF    - rlocationpath of llvm-readelf

# --- begin runfiles.bash initialization v3 ---
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^.*/$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo >&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

static_bin="$(rlocation "${STATIC_BIN}")"
shared_bin="$(rlocation "${SHARED_BIN}")"
readelf="$(rlocation "${READELF}")"

# The recorded NEEDED is either libclang_rt.<san>.so or lib<san>.shared.so.
needed_re='\(NEEDED\).*(clang_rt\.(a|t)san|(a|t)san\.shared|lib(a|t)san)'

static_needed="$("${readelf}" -d "${static_bin}" 2>/dev/null | grep -iE "${needed_re}" || true)"
shared_needed="$("${readelf}" -d "${shared_bin}" 2>/dev/null | grep -iE "${needed_re}" || true)"

if [[ -n "${static_needed}" ]]; then
  echo "Static-runtime binary unexpectedly depends on a sanitizer DSO:"
  printf '%s\n' "${static_needed}"
  exit 1
fi

if [[ -z "${shared_needed}" ]]; then
  echo "Shared-runtime binary is missing the expected sanitizer DSO dependency."
  "${readelf}" -d "${shared_bin}" || true
  exit 1
fi
