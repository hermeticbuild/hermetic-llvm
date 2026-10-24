#!/usr/bin/env bash
# Build :main for every supported glibc/architecture pair, then inspect its ELF.
# Usage: LLVM_READELF=/path/to/llvm-readelf ./glibc_matrix.sh /absolute/output
# Run from e2e/rules_cc. Outputs and logs remain outside the source checkout.
set -euo pipefail

output=${1:?usage: glibc_matrix.sh /absolute/output}
case "$output" in /*) ;; *) echo 'output must be absolute' >&2; exit 1 ;; esac
readelf=${LLVM_READELF:-llvm-readelf}
mkdir -p "$output"
bazel --output_base="$output/bazel" query --config=remote \
    'filter("linux_(x86_64|aarch64|armv7|s390x|riscv64)_gnu[.]", @llvm//platforms:all)' \
    > "$output/platforms.txt" 2> "$output/platforms.log"
expected=$(wc -l < "$output/platforms.txt" | tr -d ' ')
[[ "$expected" -gt 0 ]]
printf '%s\n' "$expected" > "$output/expected-builds.txt"
: > "$output/builds.complete"
manifest="$output/builds.tsv"
printf 'arch\tglibc\tresult\n' > "$manifest"
printf 'arch\tglibc\tbinary\tsha256\n' > "$output/artifacts.tsv"

inspect() {
    local arch=$1 version=$2 binary=$3 report=$4
    "$readelf" -h -l -d -V "$binary" > "$report"
    case "$arch" in
        x86_64) grep -q 'Machine:.*Advanced Micro Devices X86-64' "$report" ;;
        aarch64) grep -q 'Machine:.*AArch64' "$report" ;;
        armv7) grep -q 'Machine:.*ARM' "$report" ;;
        s390x) grep -q 'Machine:.*IBM S/390' "$report" ;;
        riscv64) grep -q 'Machine:.*RISC-V' "$report" ;;
    esac
    grep -q 'Type:.*EXEC' "$report"
    case "$arch" in
        x86_64) loader=ld-linux-x86-64.so.2 ;;
        aarch64) loader=ld-linux-aarch64.so.1 ;;
        armv7) loader=ld-linux-armhf.so.3 ;;
        s390x) loader=ld64.so.1 ;;
        riscv64) loader=ld-linux-riscv64-lp64d.so.1 ;;
    esac
    grep -q "Requesting program interpreter: .*/$loader" "$report"
    grep -q 'Shared library: \[libc.so.6\]' "$report"
    # Inspect version needs, rather than inferring compatibility from linkage.
    awk -v selected="$version" '
        BEGIN { split(selected, target, ".") }
        /Name: GLIBC_[0-9]/ {
            for (i = 1; i <= NF; ++i) if ($i ~ /^GLIBC_[0-9]/) {
                sub(/^GLIBC_/, "", $i)
                split($i, actual, ".")
                if (actual[1] > target[1] ||
                    (actual[1] == target[1] && actual[2] > target[2])) {
                    print "requires glibc " $i " newer than " selected > "/dev/stderr"
                    exit 1
                }
            }
        }
    ' "$report"
}

for arch in x86_64 aarch64 armv7 s390x riscv64; do
    echo "BUILD architecture matrix: $arch"
    bazel --output_base="$output/bazel" build --config=remote \
        "//:glibc_build_matrix_$arch" > "$output/$arch-build.log" 2>&1
    bazel --output_base="$output/bazel" cquery --config=remote \
        "//:glibc_build_matrix_$arch" --output=files \
        > "$output/$arch-files.txt" 2> "$output/$arch-files.log"
    while IFS= read -r platform; do
        pair=${platform##*:linux_}
        [[ "${pair%%_gnu.*}" == "$arch" ]] || continue
        version=${pair##*_gnu.}
        directory="$output/$arch/$version"
        mkdir -p "$directory"
        binary=$(awk -v prefix="bazel-out/linux_${arch}_gnu.$version-" \
            'index($0, prefix) == 1 && /\/bin\/main$/ { print }' "$output/$arch-files.txt")
        [[ -n "$binary" && "$binary" != *$'\n'* ]]
        [[ ! -e "$directory/main" ]] || chmod u+w "$directory/main"
        cp "$binary" "$directory/main"
        inspect "$arch" "$version" "$directory/main" "$directory/main.elf.txt"
        digest=$(shasum -a 256 "$directory/main")
        printf '%s\t%s\tmain\t%s\n' "$arch" "$version" "${digest%% *}" >> "$output/artifacts.tsv"
        printf '%s\t%s\tpass\n' "$arch" "$version" >> "$manifest"
        echo "PASS $arch glibc $version"
    done < "$output/platforms.txt"
done
[[ $(awk 'END { print NR - 1 }' "$manifest") == "$expected" ]]
if bazel --output_base="$output/bazel" query --config=remote \
    '@llvm//platforms:linux_riscv64_gnu.2.17' > "$output/unsupported-platform.log" 2>&1; then
    echo 'Unsupported RISC-V/glibc pair was published' >&2
    exit 1
fi
grep -q 'no such target' "$output/unsupported-platform.log"
if bazel --output_base="$output/bazel" build --config=remote \
    @llvm//runtimes/glibc:generate_glibc_stubs \
    --platforms=//:glibc_riscv64_2_17_unsupported \
    > "$output/unsupported-stubs.log" 2>&1; then
    echo 'Unsupported RISC-V/glibc pair generated stubs' >&2
    exit 1
fi
grep -q 'RISC-V requires glibc >= 2.27' "$output/unsupported-stubs.log"
printf '%s\n' "$expected" > "$output/builds.complete"
printf 'All %s builds and %s ELF inspections passed.\n' "$expected" "$expected"
