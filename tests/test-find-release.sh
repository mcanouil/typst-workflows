#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/find-release/find-release.sh"

value() {
  sed -n "s/^$1=//p" <<<"$2"
}

cat >"${SCRATCH}/releases.json" <<'EOF'
[
  {"id": 3, "tag_name": "0.8.0", "draft": true, "target_commitish": "abc123",
   "assets": [{"id": 31, "name": "demo-0.8.0.tar.gz"}, {"id": 32, "name": "demo-0.8.0.zip"}]},
  {"id": 2, "tag_name": "0.7.0", "draft": false, "target_commitish": "main",
   "assets": [{"id": 21, "name": "demo-0.7.0.tar.gz"}]},
  {"id": 4, "tag_name": "0.9.0", "draft": true, "target_commitish": "def456", "assets": []},
  {"id": 5, "tag_name": "0.9.0", "draft": true, "target_commitish": "fed654", "assets": []}
]
EOF

out="$("${script}" 0.8.0 demo-0.8.0.tar.gz <"${SCRATCH}/releases.json")"
assert_eq "draft" "$(value state "${out}")" "draft state"
assert_eq "3" "$(value id "${out}")" "draft id"
assert_eq "abc123" "$(value target "${out}")" "draft target"
assert_eq "31" "$(value asset_id "${out}")" "draft asset"

out="$("${script}" 0.7.0 demo-0.7.0.tar.gz <"${SCRATCH}/releases.json")"
assert_eq "published" "$(value state "${out}")" "published state"
assert_eq "21" "$(value asset_id "${out}")" "published asset"

out="$("${script}" 0.8.0 other-0.8.0.tar.gz <"${SCRATCH}/releases.json")"
assert_eq "" "$(value asset_id "${out}")" "missing asset"

out="$("${script}" 0.6.0 demo-0.6.0.tar.gz <"${SCRATCH}/releases.json")"
assert_eq $'state=none\nid=\ntarget=\nasset_id=' "${out}" "no release"

status=0
err="$("${script}" 0.9.0 demo-0.9.0.tar.gz <"${SCRATCH}/releases.json" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "two drafts"
assert_contains "${err}" "2 draft releases name 0.9.0" "two drafts message"

status=0
err="$(printf 'not json' | "${script}" 0.8.0 demo-0.8.0.tar.gz 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "bad JSON"
assert_contains "${err}" "is not a JSON list of releases" "bad JSON message"
