#!/usr/bin/env bash
# Runs shellcheck and shfmt over two lists of globs, and refuses a list that matches nothing.
set -euo pipefail

usage='usage: lint-shell.sh <shellcheck-globs> <shfmt-globs>'
shellcheck_globs="${1:?${usage}}"
shfmt_globs="${2:?${usage}}"

shopt -s nullglob

expand() {
  local globs="$1"
  local -a files
  # shellcheck disable=SC2206 # the input is a list of globs to expand.
  files=(${globs})
  if [[ ${#files[@]} -eq 0 ]]; then
    printf 'nothing matched: %s\n' "${globs}" >&2
    return 1
  fi
  printf '%s\n' "${files[@]}"
}

mapfile -t shellcheck_files < <(expand "${shellcheck_globs}")
[[ ${#shellcheck_files[@]} -gt 0 ]] || exit 1
mapfile -t shfmt_files < <(expand "${shfmt_globs}")
[[ ${#shfmt_files[@]} -gt 0 ]] || exit 1

status=0
shellcheck "${shellcheck_files[@]}" || status=1
shfmt -d "${shfmt_files[@]}" || status=1
exit "${status}"
