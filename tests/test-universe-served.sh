#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/universe-served/served.sh"
index="${SCRATCH}/index.json"

cat >"${index}" <<'EOF'
[
  {"name": "demo", "version": "0.1.0", "compiler": "0.15.0"},
  {"name": "other", "version": "0.2.0", "compiler": "0.15.0"}
]
EOF

assert_eq "served=true" "$("${script}" demo 0.1.0 "${index}")" "served"
assert_eq "served=false" "$("${script}" demo 0.2.0 "${index}")" "other version of the same package"
assert_eq "served=false" "$("${script}" fresh 0.1.0 "${index}")" "unknown package"

printf '{"name": "demo"}\n' >"${SCRATCH}/object.json"
status=0
err="$("${script}" demo 0.1.0 "${SCRATCH}/object.json" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "not an array"
assert_contains "${err}" "is not a package index" "not an array message"
