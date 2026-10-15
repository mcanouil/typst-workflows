#!/usr/bin/env bash
# Fills the Typst package cache with the dependencies of a package and of its
# template, by compiling a file that imports the package and the template
# entrypoint. typst-package-check reads dependencies from that cache and never
# downloads them.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'fill: %s\n' "$*" >&2
  fi
  exit 1
}

usage='usage: fill.sh <package-dir> <name> <version> <work-dir>'
package="${1:?${usage}}"
name="${2:?${usage}}"
version="${3:?${usage}}"
work="${4:?${usage}}"
[[ -f "${package}/typst.toml" ]] || die "${package} has no typst.toml."

mkdir -p "${work}/packages/preview/${name}"
ln -sfn "${package}" "${work}/packages/preview/${name}/${version}"
printf '#import "@preview/%s:%s": *\n' "${name}" "${version}" >"${work}/probe.typ"

sources=("${work}/probe.typ")
template="$(yq -p toml -oy '.template | select(.) | .path + "/" + .entrypoint' "${package}/typst.toml")"
if [[ -n "${template}" ]]; then
  sources+=("${package}/${template}")
fi

for source in "${sources[@]}"; do
  typst compile --package-path "${work}/packages" "${source}" "${work}/out.pdf" ||
    die "Typst could not compile ${source} to fill the package cache. Fix the error above in the package, then dispatch the release with bump none."
done
