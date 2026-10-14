#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

refs="$(grep -rhoE 'mcanouil/typst-workflows/[^ "]+' "${ROOT}/.github/workflows" "${ROOT}/actions" || true)"
[[ -n "${refs}" ]] || {
  echo "  no internal reference found" >&2
  exit 1
}

bad="$(grep -vE '@v1$' <<<"${refs}" || true)"
assert_eq "" "${bad}" "internal references that are not @v1"
