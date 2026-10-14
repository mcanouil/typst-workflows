#!/usr/bin/env bash
# Assertions shared by the tests/test-*.sh files.
set -euo pipefail

SCRATCH="$(mktemp -d)"
trap 'rm -rf "${SCRATCH}"' EXIT
export SCRATCH

assert_eq() {
  if [[ "$1" != "$2" ]]; then
    printf '  %s: expected [%s], got [%s]\n' "$3" "$1" "$2" >&2
    exit 1
  fi
}

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    printf '  %s: [%s] does not contain [%s]\n' "$3" "$1" "$2" >&2
    exit 1
  fi
}

assert_status() {
  if [[ "$1" -ne "$2" ]]; then
    printf '  %s: expected exit %s, got %s\n' "$3" "$1" "$2" >&2
    exit 1
  fi
}
