#!/usr/bin/env bash

set -euo pipefail

test -x "${1:?error_header_binary path required}"
test -f "${2:?external_include_paths_glibc_crt1 path required}"
