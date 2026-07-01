#!/usr/bin/env bash

set -euo pipefail

"${1:?nasm path required}" -v
