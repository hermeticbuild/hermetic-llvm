#!/usr/bin/env bash
set -euo pipefail
for resource in "$@"; do
  [[ $(<"$resource/include/builtin.h") == "// compiler header" ]]
  [[ $(<"$resource/share/ignorelist.txt") == "compiler ignorelist" ]]
  [[ $(<"$resource/lib/target/sentinel.txt") == "target runtime" ]]
  [[ ! -e "$resource/lib/host/sentinel.txt" ]]
done
