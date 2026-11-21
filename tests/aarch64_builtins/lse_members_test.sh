#!/bin/sh
# The aarch64 builtins archive keeps one lse_<pat>_<size>_<model>.o per outline
# atomic helper, built from lse.S copies written when llvm-project is fetched.
set -eu
members=$(grep -ao 'lse_[a-z]*_[0-9]*_[0-9]*\.pic\.o' "$1" | sort -u | wc -l)
if [ "$members" -ne 125 ]; then
    echo "$1 has $members lse_*.o members, want 125" >&2
    exit 1
fi
