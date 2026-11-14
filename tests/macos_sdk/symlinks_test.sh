#!/bin/sh
# The macOS SDK repo holds copies of header files, not file symlinks.
set -eu
sysroot=$(readlink -f "$1")
header="$sysroot/usr/include/pthread.h"
if [ ! -f "$header" ] || [ -L "$header" ]; then
    echo "$header is not a regular file" >&2
    exit 1
fi
