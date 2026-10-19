#!/usr/bin/env bash
# Moves an existing draft release to a commit, replaces its notes and uploads
# its two archives. Reads VERSION, NAME, SHA (the target commit), NOTES (the
# notes file) and ASSETS_DIR (where <name>-<version>.tar.gz and .zip are) from
# the environment. gh reads GH_TOKEN.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'update-draft: %s\n' "$*" >&2
  fi
  exit 1
}

version="${VERSION:?VERSION is not set.}"
name="${NAME:?NAME is not set.}"
sha="${SHA:?SHA is not set.}"
notes="${NOTES:?NOTES is not set.}"
assets_dir="${ASSETS_DIR:?ASSETS_DIR is not set.}"

tarball="${assets_dir}/${name}-${version}.tar.gz"
zipball="${assets_dir}/${name}-${version}.zip"
for archive in "${tarball}" "${zipball}"; do
  [[ -f "${archive}" ]] || die "the archive ${archive} does not exist, so the draft ${version} cannot be updated."
done

gh release edit "${version}" --target "${sha}" --notes-file "${notes}" ||
  die "could not edit the draft ${version}."
gh release upload "${version}" --clobber \
  "${tarball}#${name} ${version} (tar.gz)" \
  "${zipball}#${name} ${version} (zip)" ||
  die "could not upload the archives to the draft ${version}."
