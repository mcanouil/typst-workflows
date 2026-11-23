#!/usr/bin/env bash
# Prints the Quarto version to install: the requested one, or, for `auto`,
# `pre-release` when an extension under the extensions directory needs a Quarto
# newer than the latest stable release, and `release` otherwise.
#
# Usage: resolve.sh <requested> <extensions-dir>
# QUARTO_STABLE overrides the latest stable version, which is otherwise read
# from quarto.org.
set -euo pipefail

requested="${1:?resolve: requested version missing; got none. Pass auto, release, pre-release or a version.}"
extensions_dir="${2:?resolve: extensions directory missing; got none. Pass the path to docs/_extensions.}"

if [[ "${requested}" != "auto" ]]; then
  printf '%s\n' "${requested}"
  exit 0
fi

required=""
if [[ -d "${extensions_dir}" ]]; then
  while IFS= read -r manifest; do
    bound="$(sed -nE 's/^quarto-required:[[:space:]]*["'\'']?>=[[:space:]]*([0-9]+(\.[0-9]+)*).*/\1/p' "${manifest}" | head -n 1)"
    if [[ -n "${bound}" ]]; then
      required="$(printf '%s\n%s\n' "${required}" "${bound}" | sed '/^$/d' | sort -V | tail -n 1)"
    fi
  done < <(find "${extensions_dir}" -name '_extension.yml' -o -name '_extension.yaml')
fi

if [[ -z "${required}" ]]; then
  echo release
  exit 0
fi

stable="${QUARTO_STABLE:-}"
if [[ -z "${stable}" ]]; then
  stable="$(curl -fsSL https://quarto.org/docs/download/_download.json | jq -er '.version')" || {
    echo "resolve: cannot read the latest Quarto version from quarto.org; got no version. Pass quarto-version explicitly." >&2
    exit 1
  }
fi

newest="$(printf '%s\n%s\n' "${required}" "${stable}" | sort -V | tail -n 1)"
if [[ "${newest}" == "${stable}" ]]; then
  echo release
else
  echo pre-release
fi
