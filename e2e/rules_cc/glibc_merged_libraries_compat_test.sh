#!/usr/bin/env bash
set -euo pipefail
# Old DSOs still require the pre-merge libraries; new callers need glibc 2.38.
grep -q 'pthread_create@@GLIBC_' "$1"
grep -q 'dlopen@@GLIBC_' "$2"
grep -q '__isoc23_strtol@@GLIBC_2.38' "$3"
