#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/setup-typst/read-compiler.sh"

printf '[package]\nname = "x"\ncompiler = "0.15.0"\n' >"${SCRATCH}/plain.toml"
assert_eq "0.15.0" "$("${script}" "${SCRATCH}/plain.toml")" "plain"

printf 'compiler   =   "0.14.2"\n' >"${SCRATCH}/spaced.toml"
assert_eq "0.14.2" "$("${script}" "${SCRATCH}/spaced.toml")" "spaced"

printf '# compiler = "9.9.9"\nname = "x"\n' >"${SCRATCH}/comment.toml"
status=0
err="$("${script}" "${SCRATCH}/comment.toml" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "comment only"
assert_contains "${err}" "compiler not found in ${SCRATCH}/comment.toml" "comment only message"

status=0
err="$("${script}" "${SCRATCH}/absent.toml" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "absent file"
assert_contains "${err}" "manifest not found: ${SCRATCH}/absent.toml" "absent file message"
