#!/usr/bin/env bash
# Reads the response of `gh api -i user` on stdin, and refuses any token but a
# classic personal access token with the public_repo scope alone. GitHub lets
# only such a token open a pull request on typst/packages from a fork, and the
# single scope keeps a leaked token away from everything else.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'check-token: %s\n' "$*" >&2
  fi
  exit 1
}

headers="$(tr -d '\r')"
if ! scopes="$(awk -F':[[:space:]]*' '
  tolower($1) == "x-oauth-scopes" { print $2; found = 1; exit }
  END { exit !found }
' <<<"${headers}")"; then
  die "the pull request token is not a classic personal access token. Create a classic token with the public_repo scope alone, and store it as UNIVERSE_TOKEN on the typst-universe environment."
fi
if [[ "${scopes}" != "public_repo" ]]; then
  die "the pull request token has the scopes '${scopes}'. Create a classic token with the public_repo scope alone, and store it as UNIVERSE_TOKEN on the typst-universe environment."
fi
printf 'scopes=%s\n' "${scopes}"
