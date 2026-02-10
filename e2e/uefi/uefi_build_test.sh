#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo >&2 "Usage: $0 <x86_64 app>"
    exit 1
fi

app="$1"
if [[ ! -s "$app" ]]; then
    echo >&2 "Missing or empty app: $app"
    exit 1
fi
