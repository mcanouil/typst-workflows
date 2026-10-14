#!/usr/bin/env bash
# Prints the Typst compiler version that a typst.toml manifest pins.
set -euo pipefail

manifest="${1:?usage: read-compiler.sh <typst.toml>}"

if [[ ! -f "${manifest}" ]]; then
  printf 'manifest not found: %s\n' "${manifest}" >&2
  exit 1
fi

version="$(awk -F'"' '/^compiler[[:space:]]*=/ { print $2; exit }' "${manifest}")"
if [[ -z "${version}" ]]; then
  printf 'compiler not found in %s\n' "${manifest}" >&2
  exit 1
fi

printf '%s\n' "${version}"
