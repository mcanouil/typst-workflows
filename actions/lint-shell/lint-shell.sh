#!/usr/bin/env bash
# Runs shellcheck and shfmt over two lists of globs, and refuses a list that matches nothing.
set -euo pipefail

usage='usage: lint-shell.sh <shellcheck-globs> <shfmt-globs>'
shellcheck_globs="${1:?${usage}}"
shfmt_globs="${2:?${usage}}"

shopt -s nullglob

# Each glob must match on its own: a path that moved fails even when the
# other globs in its list still match.
expand() {
  local glob
  local -a globs matched
  read -r -a globs <<<"$1"
  for glob in "${globs[@]}"; do
    # shellcheck disable=SC2206 # the input is a glob to expand.
    matched=(${glob})
    if [[ ${#matched[@]} -eq 0 ]]; then
      printf 'nothing matched: %s\n' "${glob}" >&2
      return 1
    fi
    printf '%s\n' "${matched[@]}"
  done
}

shellcheck_list="$(expand "${shellcheck_globs}")" || exit 1
shfmt_list="$(expand "${shfmt_globs}")" || exit 1
mapfile -t shellcheck_files <<<"${shellcheck_list}"
mapfile -t shfmt_files <<<"${shfmt_list}"

status=0
shellcheck "${shellcheck_files[@]}" || status=1
shfmt -d "${shfmt_files[@]}" || status=1
exit "${status}"
