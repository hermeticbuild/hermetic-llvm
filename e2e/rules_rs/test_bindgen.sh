#!/usr/bin/env bash

set -euo pipefail

bindings="$1"
test -s "${bindings}"
grep -q "bindgen_stddef_probe" "${bindings}"
