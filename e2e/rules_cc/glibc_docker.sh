#!/usr/bin/env bash
# Usage: ./glibc_docker.sh /absolute/matrix-output
# No consumer binaries execute until the entire cross-build matrix has passed.
set -euo pipefail
output=${1:?matrix output}
scripts=$(cd "$(dirname "$0")" && pwd)
expected=$(cat "$output/expected-builds.txt")
[[ $(cat "$output/builds.complete") == "$expected" ]]
awk -F '\t' -v expected="$expected" '
    NR == 1 { next }
    { if ($3 != "pass" || seen[$1 SUBSEP $2]++) bad=1; ++count }
    END { exit bad || count != expected }
' "$output/builds.tsv"
awk -F ':linux_' '{ split($2, pair, "_gnu[.]"); print pair[1] "\t" pair[2] }' \
    "$output/platforms.txt" | sort > "$output/expected-pairs.tsv"
awk -F '\t' 'NR > 1 { print $1 "\t" $2 }' "$output/builds.tsv" | sort > "$output/built-pairs.tsv"
cmp "$output/expected-pairs.tsv" "$output/built-pairs.tsv"
awk -F '\t' 'NR > 1 && $1 == "aarch64" { print $2 }' "$output/builds.tsv" \
    > "$output/runtime-versions.txt"
printf 'glibc\tresult\n' > "$output/runtimes.tsv"

# Pin the native ARM64 bases. GCC 4.9 builds the old release branches; GCC 13
# satisfies the compiler and binutils requirements of current glibc releases.
for specification in \
    '4.9 ubuntu:16.04@sha256:f4c51ba054967fd4b06715f1b67078efbe9ca152e8be98d8f3c1f4d08c6042f8' \
    '13 ubuntu:24.04@sha256:18b33ff3829707f31ada654a963b9ee35f2e6f0241b964bd17a22a9b330cb63d'; do
    compiler=${specification%% *}
    base=${specification#* }
    docker build --platform=linux/arm64 --build-arg "BASE_IMAGE=$base" \
        --build-arg "GCC_VERSION=$compiler" -f "$scripts/glibc_runtime.Dockerfile" \
        -t "hermetic-glibc-runtime:gcc$compiler" "$scripts" \
        > "$output/docker-gcc$compiler.log" 2>&1
done

metadata() {
    awk -F '"' -v map="$1" -v version="$2" '
        $0 ~ "^" map " = \\{" { inside=1; next }
        inside && /^}/ { exit }
        inside && $2 == version { print $4; exit }
    ' "$scripts/../../runtimes/glibc/extension/glibc.bzl"
}

while IFS= read -r version; do
    minor=${version#2.}
    if (( minor < 28 )); then compiler=4.9; else compiler=13; fi
    image="hermetic-glibc-runtime:gcc$compiler"
    directory="$output/runtime/$version"
    mkdir -p "$directory"
    url=$(metadata GLIBC_RELEASE_URLS "$version")
    if [[ -z "$url" ]]; then
        commit=$(metadata GLIBC_RELEASE_COMMITS "$version")
        [[ -n "$commit" ]]
        url="https://github.com/bminor/glibc/archive/$commit.tar.gz"
    fi
    digest=$(metadata GLIBC_RELEASE_INTEGRITY "$version")
    [[ -n "$url" && -n "$digest" ]]
    docker image inspect "$image" > "$directory/builder-image.json"
    echo "RUNTIME ARM64 glibc $version"
    if ! docker run --rm --platform=linux/arm64 \
        -v "$scripts/glibc_docker_build.sh:/run-glibc.sh:ro" \
        -v "$output/aarch64/$version:/binaries:ro" \
        -v "$output/artifacts.tsv:/artifacts.tsv:ro" \
        -v "$directory:/out" "$image" \
        bash /run-glibc.sh "$version" "$url" "$digest" \
        > "$directory/docker.log" 2>&1; then
        printf '%s\tfail\n' "$version" >> "$output/runtimes.tsv"
        tail -40 "$directory/docker.log" >&2
        exit 1
    fi
    cat "$directory/result.tsv" >> "$output/runtimes.tsv"
done < "$output/runtime-versions.txt"
awk -F '\t' -v expected="$(wc -l < "$output/runtime-versions.txt")" '
    NR == 1 { next }
    { if ($2 != "pass" || seen[$1]++) bad=1; ++count }
    END { exit bad || count != expected }
' "$output/runtimes.tsv"
echo 'All matching ARM64 runtimes passed.'
