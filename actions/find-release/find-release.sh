#!/usr/bin/env bash
# Finds the GitHub Release of a version in the list of releases on stdin, as
# `gh api --paginate repos/<repo>/releases --jq '.[]' | jq -s .` gives it.
# Prints GITHUB_OUTPUT lines: state (draft, published or none), id, target, and
# asset_id, the id of the named asset or nothing.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'find-release: %s\n' "$*" >&2
  fi
  exit 1
}

usage='usage: find-release.sh <version> <asset-name> < releases.json'
version="${1:?${usage}}"
asset="${2:?${usage}}"

releases="$(jq -c --arg v "${version}" '[.[] | select(.tag_name == $v)]' 2>/dev/null)" ||
  die "the input is not a JSON list of releases."
published="$(jq -c '[.[] | select(.draft | not)]' <<<"${releases}")"
drafts="$(jq -c '[.[] | select(.draft)]' <<<"${releases}")"
draft_count="$(jq length <<<"${drafts}")"

if [[ "$(jq length <<<"${published}")" -gt 0 ]]; then
  state="published"
  release="$(jq -c '.[0]' <<<"${published}")"
elif [[ "${draft_count}" -gt 1 ]]; then
  die "${draft_count} draft releases name ${version}. Delete all but one on the Releases page, then run the workflow again."
elif [[ "${draft_count}" -eq 1 ]]; then
  state="draft"
  release="$(jq -c '.[0]' <<<"${drafts}")"
else
  printf 'state=none\nid=\ntarget=\nasset_id=\n'
  exit 0
fi

printf 'state=%s\n' "${state}"
jq -r --arg a "${asset}" '
  "id=\(.id)",
  "target=\(.target_commitish)",
  "asset_id=\([.assets[] | select(.name == $a) | .id][0] // "")"
' <<<"${release}"
