#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/universe-submit/check-token.sh"

response() {
  printf 'HTTP/2.0 200 OK\r\n%sContent-Type: application/json\r\n\r\n{"login":"o"}\n' "$1"
}

assert_eq "scopes=public_repo" "$(response $'X-Oauth-Scopes: public_repo\r\n' | "${script}")" "classic, public_repo"

status=0
err="$(response "" | "${script}" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "fine-grained or App token"
assert_contains "${err}" "not a classic personal access token" "fine-grained message"

status=0
err="$(response $'X-Oauth-Scopes: public_repo, workflow\r\n' | "${script}" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "extra scope"
assert_contains "${err}" "has the scopes 'public_repo, workflow'" "extra scope message"
