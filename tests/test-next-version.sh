#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/.github/scripts/next-version.sh"

value() {
  sed -n "s/^$1=//p" <<<"$2"
}

out="$("${script}" minor "")"
assert_eq "v0.1.0" "$(value version "${out}")" "seeded minor"
assert_eq "v0.0.0" "$(value previous "${out}")" "seeded previous"

out="$("${script}" minor "v1.0.0")"
assert_eq "v1.1.0" "$(value version "${out}")" "minor"
assert_eq "v1.1" "$(value minor "${out}")" "minor rolling"
assert_eq "v1" "$(value major "${out}")" "major rolling"
assert_eq "v1.0.0" "$(value previous "${out}")" "previous"

out="$("${script}" patch "v1.2.3")"
assert_eq "v1.2.4" "$(value version "${out}")" "patch"

out="$("${script}" major "v1.2.3")"
assert_eq "v2.0.0" "$(value version "${out}")" "major"
assert_eq "v2.0" "$(value minor "${out}")" "major minor rolling"
assert_eq "v2" "$(value major "${out}")" "major major rolling"

status=0
err="$("${script}" huge "v1.0.0" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "unknown bump"
assert_contains "${err}" "unknown bump type 'huge'" "unknown bump message"

status=0
err="$("${script}" minor "1.0.0" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "tag without v"
assert_contains "${err}" "not a vX.Y.Z tag: 1.0.0" "tag without v message"
