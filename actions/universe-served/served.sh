#!/usr/bin/env bash
# Says whether Typst Universe serves a package version, from the index that
# packages.typst.org publishes. Prints `served=true` or `served=false`.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'served: %s\n' "$*" >&2
  fi
  exit 1
}

url="https://packages.typst.org/preview/index.json"
usage='usage: served.sh <name> <version> [index.json]'
name="${1:?${usage}}"
version="${2:?${usage}}"
index="${3:-}"

if [[ -z "${index}" ]]; then
  index="$(mktemp)"
  trap 'rm -f "${index}"' EXIT
  curl -fsSL --retry 3 "${url}" -o "${index}" ||
    die "could not download ${url}. Run the workflow again in a few minutes."
fi

jq -e 'type == "array"' "${index}" >/dev/null 2>&1 ||
  die "${3:-${url}} is not a package index: expected a JSON array of packages."

served="$(jq -r --arg n "${name}" --arg v "${version}" \
  'any(.[]; .name == $n and .version == $v)' "${index}")"
printf 'served=%s\n' "${served}"
