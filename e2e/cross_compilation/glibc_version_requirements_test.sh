#!/usr/bin/env bash
set -euo pipefail

# sh_test starts in the runfiles workspace; rootpath values are relative to it.
count=0
while read -r selected binary; do
    "${READELF}" --version-info "$binary" > "${TEST_TMPDIR}/versions.txt"
    awk -v selected="$selected" -v binary="$binary" '
        /^Version .* section/ { needs = ($2 == "needs") }
        needs && /Name: GLIBC_/ {
            for (i = 1; i <= NF; ++i) {
                if ($i == "GLIBC_PRIVATE") {
                    print binary ": requires GLIBC_PRIVATE" > "/dev/stderr"
                    exit 1
                }
                if ($i !~ /^GLIBC_[0-9]+([.][0-9]+)+$/) continue
                ++checked
                required = $i
                sub(/^GLIBC_/, "", required)
                n = split(required, actual, ".")
                m = split(selected, target, ".")
                for (j = 1; j <= n || j <= m; ++j) {
                    if (actual[j] + 0 < target[j] + 0) break
                    if (actual[j] + 0 > target[j] + 0) {
                        print binary ": requires glibc " required " newer than " selected > "/dev/stderr"
                        exit 1
                    }
                }
            }
        }
        END {
            if (!checked) {
                print binary ": no public GLIBC version needs found" > "/dev/stderr"
                exit 1
            }
        }
    ' "${TEST_TMPDIR}/versions.txt"
    count=$((count + 1))
done <<< "${GLIBC_BINARIES}"
echo "Checked glibc version requirements; binaries: $count."
