#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/run-logged/run-logged.sh"

export GITHUB_STEP_SUMMARY="${SCRATCH}/pass.md"
out="$("${script}" "Suite" "${SCRATCH}/pass.log" -- bash -c 'echo hello')"
assert_eq "hello" "${out}" "pass stdout"
assert_contains "$(cat "${SCRATCH}/pass.log")" "hello" "pass log"
assert_contains "$(cat "${GITHUB_STEP_SUMMARY}")" "## Suite" "pass heading"
assert_contains "$(cat "${GITHUB_STEP_SUMMARY}")" "- Status: passed" "pass status"

export GITHUB_STEP_SUMMARY="${SCRATCH}/fail.md"
status=0
"${script}" "Suite" "${SCRATCH}/fail.log" -- bash -c 'echo broken line; exit 3' >/dev/null || status=$?
assert_status 3 "${status}" "fail keeps the exit status through tee"
assert_contains "$(cat "${GITHUB_STEP_SUMMARY}")" "- Status: failed (exit 3)" "fail status"
assert_contains "$(cat "${GITHUB_STEP_SUMMARY}")" "broken line" "fail tail"

unset GITHUB_STEP_SUMMARY
status=0
err="$("${script}" "Suite" "${SCRATCH}/none.log" -- true 2>&1)" || status=$?
assert_status 2 "${status}" "no summary file"
assert_contains "${err}" "GITHUB_STEP_SUMMARY is not set" "no summary message"
