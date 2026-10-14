#!/usr/bin/env bash
# Runs every tests/test-*.sh file and reports the files that fail.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT

failed=0
for test_file in "${ROOT}"/tests/test-*.sh; do
  if bash "${test_file}"; then
    printf 'ok    %s\n' "${test_file##*/}"
  else
    printf 'FAIL  %s\n' "${test_file##*/}"
    failed=$((failed + 1))
  fi
done

if [[ ${failed} -gt 0 ]]; then
  printf '%d test file(s) failed.\n' "${failed}" >&2
  exit 1
fi
