#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/resolve-quarto/resolve.sh"
extensions="${SCRATCH}/_extensions"
mkdir -p "${extensions}/a/one" "${extensions}/b/two"
export QUARTO_STABLE="1.11.9"

assert_eq "1.12.0" "$("${script}" 1.12.0 "${extensions}")" "explicit version"
assert_eq "release" "$("${script}" release "${extensions}")" "explicit release"

assert_eq "release" "$("${script}" auto "${SCRATCH}/absent")" "no extensions directory"
assert_eq "release" "$("${script}" auto "${extensions}")" "no manifests"

printf 'title: One\nquarto-required: ">=1.5.0"\n' >"${extensions}/a/one/_extension.yml"
assert_eq "release" "$("${script}" auto "${extensions}")" "older requirement"

printf 'title: Two\nquarto-required: ">=1.12.1"\n' >"${extensions}/b/two/_extension.yml"
assert_eq "pre-release" "$("${script}" auto "${extensions}")" "newer requirement"

printf 'title: Two\nquarto-required: ">=1.11.9"\n' >"${extensions}/b/two/_extension.yml"
assert_eq "release" "$("${script}" auto "${extensions}")" "requirement equal to stable"

printf 'title: Two\nquarto-required: ">=1.10.0"\n' >"${extensions}/b/two/_extension.yml"
assert_eq "release" "$("${script}" auto "${extensions}")" "ten sorts below eleven"

status=0
err="$("${script}" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "no arguments"
assert_contains "${err}" "requested version missing" "no arguments message"
