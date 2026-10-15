#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

refs="$(grep -rhoE 'mcanouil/typst-workflows/[^ "]+' "${ROOT}/.github/workflows" "${ROOT}/actions" || true)"
[[ -n "${refs}" ]] || {
  echo "  no internal reference found" >&2
  exit 1
}

bad="$(grep -vE '@v2$' <<<"${refs}" || true)"
assert_eq "" "${bad}" "internal references that are not @v2"

# A reference to an action that does not exist passes actionlint and fails only
# when a job sets up, so each one must name a directory with an action.yml.
missing=""
while IFS= read -r action; do
  [[ -f "${ROOT}/${action}/action.yml" ]] || missing+="${action} "
done < <(grep -oE '^mcanouil/typst-workflows/actions/[^@]+' <<<"${refs}" | sed 's|^mcanouil/typst-workflows/||' | sort -u)
assert_eq "" "${missing}" "internal action references with no action.yml"
