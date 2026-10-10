#!/usr/bin/env bash
# Rebuilds an LLVM prebuilt release from its commit (the current directory)
# with that commit's own release script and compares the archives with the
# published ones.
#
# Usage: verify.sh <release tag> <all release tags in chain order...>
#
# The build accepts no cached results, so every action is executed. Release
# archives downloaded during the build must come from releases published before
# the first release in the chain or from releases earlier in the chain, which
# the preceding jobs have already verified.

set -euo pipefail

tag="$1"
shift
known_archives="${VERIFY_DIR}/.github/verify-prebuilts/known-archives.tsv"
first_unverified_date="$(awk -F'\t' -v t="$1" '$2 == t {print $3; exit}' "${known_archives}")"
[[ -n "${first_unverified_date}" ]]

verified_tags=()
for t in "$@"; do
  [[ "${t}" == "${tag}" ]] && break
  verified_tags+=("${t}")
done

cat >> "${HOME}/.bazelrc" <<EOF
common --remote_header=x-buildbuddy-api-key=4jtaxdhxtyu4ylxdEwI7
common --bes_header=x-buildbuddy-api-key=4jtaxdhxtyu4ylxdEwI7
common --remote_instance_name=$(python3 -c "import uuid; print(uuid.uuid4())")
common --noremote_accept_cached
common --noremote_upload_local_results
EOF

build_log="${RUNNER_TEMP}/build.log"
GITHUB_REF_NAME="${tag}" bash .github/workflows/llvm-prebuilt.sh 2>&1 | tee "${build_log}"

failed=0
summary="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
echo "## ${tag} ($(git rev-parse --short HEAD))" >> "${summary}"

# Every action must have been executed, not taken from a cache.
echo "### Build" >> "${summary}"
while read -r line; do
  echo "- \`${line}\`" >> "${summary}"
  if [[ "${line}" == *"cache hit"* ]]; then
    echo "::error::Build used cached results: ${line}"
    failed=1
  fi
done < <(grep -o -E 'INFO: [0-9]+ processes: .*' "${build_log}")

# Release archives downloaded during the build (bootstrap seeds and extras).
echo "### Downloaded release archives" >> "${summary}"
found_archive=0
for cache_dir in "${HOME}/.cache/bazel-repo/content_addressable/sha256" "${HOME}/.cache/bazel/_bazel_${USER}/cache/repos/v1/content_addressable/sha256"; do
  [[ -d "${cache_dir}" ]] || continue
  for entry in "${cache_dir}"/*; do
    digest="$(basename "${entry}")"
    while IFS=$'\t' read -r _ archive_tag published name; do
      found_archive=1
      status="published before the first release in the chain"
      if [[ ! "${published}" < "${first_unverified_date}" ]]; then
        status="not verified"
        for t in "${verified_tags[@]}"; do
          [[ "${t}" == "${archive_tag}" ]] && status="verified earlier in this chain"
        done
      fi
      echo "- ${name} (${archive_tag}): ${status}" >> "${summary}"
      if [[ "${status}" == "not verified" ]]; then
        echo "::error::The build downloaded ${name} from ${archive_tag}, which has not been verified"
        failed=1
      fi
    done < <(awk -F'\t' -v d="${digest}" '$1 == d' "${known_archives}")
  done
done
if [[ "${found_archive}" == 0 ]]; then
  echo "::error::Could not find any downloaded release archive in the repository cache"
  failed=1
fi

# The rebuilt archives must be identical to the published ones.
echo "### Archives" >> "${summary}"
published="${RUNNER_TEMP}/published-SHA256.txt"
curl -fsSL "https://github.com/hermeticbuild/hermetic-llvm/releases/download/${tag}/SHA256.txt" -o "${published}"
echo "| Archive | Published | Rebuilt |" >> "${summary}"
echo "| --- | --- | --- |" >> "${summary}"
while read -r expected name; do
  actual="$(awk -v n="${name}" '$2 == n {print $1}' release/SHA256.txt)"
  echo "| ${name} | \`${expected:0:12}\` | \`${actual:0:12}\` $([[ "${actual}" == "${expected}" ]] && echo ✅ || echo ❌) |" >> "${summary}"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "::error::${name} differs from the published archive (published ${expected}, rebuilt ${actual:-missing})"
    failed=1
  fi
done < "${published}"
if [[ "$(wc -l < release/SHA256.txt)" != "$(wc -l < "${published}")" ]]; then
  echo "::error::The rebuild produced a different set of archives than the release"
  failed=1
fi

exit "${failed}"
