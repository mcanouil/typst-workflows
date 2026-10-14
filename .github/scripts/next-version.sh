#!/usr/bin/env bash
# Prints the next release and its rolling tags, as GITHUB_OUTPUT lines, from a
# bump type and the latest vX.Y.Z tag. No tag at all seeds from v0.0.0.
set -euo pipefail

usage='usage: next-version.sh <patch|minor|major> [latest-tag]'
bump="${1:?${usage}}"
latest="${2:-v0.0.0}"

if [[ ! "${latest}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'not a vX.Y.Z tag: %s\n' "${latest}" >&2
  exit 1
fi

IFS=. read -r major minor patch <<<"${latest#v}"
case "${bump}" in
major)
  major=$((major + 1))
  minor=0
  patch=0
  ;;
minor)
  minor=$((minor + 1))
  patch=0
  ;;
patch)
  patch=$((patch + 1))
  ;;
*)
  printf "unknown bump type '%s': expected patch, minor, or major\n" "${bump}" >&2
  exit 1
  ;;
esac

printf 'version=v%s.%s.%s\n' "${major}" "${minor}" "${patch}"
printf 'minor=v%s.%s\n' "${major}" "${minor}"
printf 'major=v%s\n' "${major}"
printf 'previous=%s\n' "${latest}"
