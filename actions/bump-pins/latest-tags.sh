#!/usr/bin/env bash
# Prints the input lines of bump-pins.sh: the latest release tag of Typst and
# of each package in the PACKAGES environment variable.
#
#   PACKAGES='<YAML list of {name, repository, file}>' latest-tags.sh <typst.toml>
#
# Each line is tab-separated: name, file, repository, tag.
set -euo pipefail

manifest="${1:?usage: latest-tags.sh <typst.toml>}"
PACKAGES="${PACKAGES:-}"

latest() {
  local tag
  if ! tag="$(gh api "repos/$1/releases/latest" --jq .tag_name)" || [[ -z "${tag}" ]]; then
    printf 'could not read the latest release of %s. Check the repository name and that it publishes releases.\n' "$1" >&2
    return 1
  fi
  printf '%s\n' "${tag}"
}

rows=""
if [[ -n "${PACKAGES//[[:space:]]/}" ]]; then
  if ! kind="$(yq -r 'tag' <<<"${PACKAGES}" 2>&1)"; then
    printf 'could not parse packages as YAML: %s\n' "${kind}" >&2
    exit 1
  fi
  if [[ "${kind}" != "!!seq" ]]; then
    printf 'packages is not a YAML list. Write one "- name: ..." entry per package.\n' >&2
    exit 1
  fi
  rows="$(yq -r '.[] | [(.name // ""), (.repository // ""), (.file // "")] | @tsv' <<<"${PACKAGES}")"
fi

tag="$(latest typst/typst)"
printf 'typst\t%s\ttypst/typst\t%s\n' "${manifest}" "${tag}"

while IFS=$'\t' read -r name repository file; do
  [[ -n "${name}${repository}${file}" ]] || continue
  if [[ -z "${name}" || -z "${repository}" || -z "${file}" ]]; then
    printf 'every entry of packages needs name, repository and file.\n' >&2
    exit 1
  fi
  tag="$(latest "${repository}")"
  printf '%s\t%s\t%s\t%s\n' "${name}" "${file}" "${repository}" "${tag}"
done <<<"${rows}"
