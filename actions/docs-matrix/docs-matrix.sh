#!/usr/bin/env bash
# Prints the docs render matrix and the versions.json payload, as GITHUB_OUTPUT
# lines, from the site URL in a Quarto configuration and the latest version tag.
set -euo pipefail

usage='usage: docs-matrix.sh <quarto-yml> [latest-tag]'
quarto_yml="${1:?${usage}}"
tag="${2:-}"

# The value after `site-url:`, without a YAML anchor (`&name`) or quotes.
site_url="$(awk '
  /^[[:space:]]*site-url:/ {
    sub(/^[[:space:]]*site-url:[[:space:]]*/, "")
    sub(/^&[^[:space:]]+[[:space:]]+/, "")
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
site_url="${site_url%/}"

if [[ -n "${tag}" ]]; then
  matrix="$(jq -nc --arg tag "${tag}" '{include: [
    {profile: "release", ref: $tag, version: $tag, assets_dir: ""},
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
