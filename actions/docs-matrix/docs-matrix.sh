#!/usr/bin/env bash
# Prints the docs render matrix and the versions.json payload, as GITHUB_OUTPUT
# lines, from the site URL in a Quarto configuration and the latest version tag.
set -euo pipefail

usage='usage: docs-matrix.sh <quarto-yml> [latest-tag] [main-as-latest]'
quarto_yml="${1:?${usage}}"
tag="${2:-}"
main_as_latest="${3:-false}"

if [[ "${main_as_latest}" != "true" && "${main_as_latest}" != "false" ]]; then
  printf 'main-as-latest must be true or false; got %s\n' "${main_as_latest}" >&2
  exit 1
fi

# The `site-url:` under the top-level `website:` key, without a YAML anchor
# (`&name`), an inline comment, or quotes. Other keys may hold a `site-url` too,
# such as an extension option that repeats it through an alias.
site_url="$(awk '
  /^[^[:space:]#]/ { in_website = ($0 ~ /^website:/) }
  in_website && /^[[:space:]]+site-url:/ {
    sub(/^[[:space:]]*site-url:[[:space:]]*/, "")
    sub(/^&[^[:space:]]+[[:space:]]+/, "")
    sub(/[[:space:]]+#.*$/, "")
    gsub(/["\047]/, "")
    sub(/[[:space:]]+$/, "")
    print
    exit
  }
' "${quarto_yml}")"
if [[ -z "${site_url}" ]]; then
  printf 'site-url not found in %s\n' "${quarto_yml}" >&2
  exit 1
fi
if [[ "${site_url}" == \** ]]; then
  printf 'website.site-url in %s is an alias (%s); write the URL there and the alias elsewhere\n' \
    "${quarto_yml}" "${site_url}" >&2
  exit 1
fi
site_url="${site_url%/}"

if [[ -n "${tag}" ]]; then
  release_ref="${tag}"
  [[ "${main_as_latest}" == "true" ]] && release_ref=""
  matrix="$(jq -nc --arg tag "${tag}" --arg ref "${release_ref}" '{include: [
    {profile: "release", ref: $ref, version: $tag, assets_dir: ""},
    {profile: "dev", ref: "", version: "dev", assets_dir: "docs/_site/dev"}
  ]}')"
  versions="$(jq -nc --arg tag "${tag}" --arg site "${site_url}" '[
    {version: $tag, url: ($site + "/"), latest: true},
    {version: "dev", url: ($site + "/dev/")}
  ]')"
else
  matrix="$(jq -nc '{include: [
    {profile: "no-release", ref: "", version: "dev", assets_dir: "docs/_site"}
  ]}')"
  versions="$(jq -nc --arg site "${site_url}" '[{version: "dev", url: ($site + "/")}]')"
fi

printf 'matrix=%s\n' "${matrix}"
printf 'versions=%s\n' "${versions}"
