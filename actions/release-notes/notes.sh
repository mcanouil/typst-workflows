#!/usr/bin/env bash
# Prints the CHANGELOG.md section of a version: the lines under its
# `## X.Y.Z (date)` heading, up to the next level-two heading, without the blank
# lines that open it.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'notes: %s\n' "$*" >&2
  fi
  exit 1
}

usage='usage: notes.sh <changelog> <version>'
changelog="${1:?${usage}}"
version="${2:?${usage}}"
[[ -f "${changelog}" ]] || die "${changelog} does not exist."

notes="$(awk -v heading="## ${version} (" '
  index($0, heading) == 1 { inside = 1; next }
  /^## / && inside { exit }
  inside
' "${changelog}" | sed '/./,$!d')"

if [[ -z "${notes//[[:space:]]/}" ]]; then
  die "${changelog} has no notes under a '## ${version} (YYYY-MM-DD)' heading. tools/bump-version.sh writes that heading from '## Unreleased'; add the notes there first."
fi
printf '%s\n' "${notes}"
