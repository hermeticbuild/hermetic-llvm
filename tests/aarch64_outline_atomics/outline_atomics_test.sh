#!/bin/sh
set -eu

helpers() {
    grep -aoE 'lse_[a-z]+_[0-9]+_[0-9]+(\.pic)?\.(o|obj)' "$1" | sort -u | wc -l
}

if [ "$(helpers "$1")" -eq 0 ]; then
    echo "$1 has no lse_* helpers, want them on linux" >&2
    exit 1
fi
for archive in "$2" "$3"; do
    n=$(helpers "$archive")
    if [ "$n" -ne 0 ]; then
        echo "$archive has $n lse_* helpers, want none" >&2
        exit 1
    fi
done
