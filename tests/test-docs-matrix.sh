#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/docs-matrix/docs-matrix.sh"

value() {
  sed -n "s/^$1=//p" <<<"$2"
}

printf 'website:\n  site-url: https://m.canouil.dev/pkg\n' >"${SCRATCH}/plain.yml"
out="$("${script}" "${SCRATCH}/plain.yml" "1.2.0")"
assert_eq '["release","dev"]' "$(value matrix "${out}" | jq -c '[.include[].profile]')" "tagged profiles"
assert_eq '["1.2.0",""]' "$(value matrix "${out}" | jq -c '[.include[].ref]')" "tagged refs"
assert_eq '["","docs/_site/dev"]' "$(value matrix "${out}" | jq -c '[.include[].assets_dir]')" "tagged assets"
assert_eq '["https://m.canouil.dev/pkg/","https://m.canouil.dev/pkg/dev/"]' "$(value versions "${out}" | jq -c '[.[].url]')" "tagged urls"
assert_eq 'true' "$(value versions "${out}" | jq -c '.[0].latest')" "latest flag"

out="$("${script}" "${SCRATCH}/plain.yml" "1.2.0" "true")"
assert_eq '["release","dev"]' "$(value matrix "${out}" | jq -c '[.include[].profile]')" "main-as-latest profiles"
assert_eq '["",""]' "$(value matrix "${out}" | jq -c '[.include[].ref]')" "main-as-latest renders the calling ref at the root"
assert_eq '["1.2.0","dev"]' "$(value matrix "${out}" | jq -c '[.include[].version]')" "main-as-latest keeps the tag version"
assert_eq '"1.2.0"' "$(value versions "${out}" | jq -c '.[0].version')" "main-as-latest versions"

out="$("${script}" "${SCRATCH}/plain.yml" "" "true")"
assert_eq '["no-release"]' "$(value matrix "${out}" | jq -c '[.include[].profile]')" "main-as-latest before the first tag"

status=0
err="$("${script}" "${SCRATCH}/plain.yml" "1.2.0" "yes" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "main-as-latest not a boolean"
assert_contains "${err}" "main-as-latest must be true or false; got yes" "main-as-latest message"

printf 'website:\n  site-url: &site-url https://m.canouil.dev/pkg\n' >"${SCRATCH}/anchor.yml"
out="$("${script}" "${SCRATCH}/anchor.yml" "1.2.0")"
assert_eq '"https://m.canouil.dev/pkg/"' "$(value versions "${out}" | jq -c '.[0].url')" "anchored site-url"

printf 'website:\n  site-url: "https://m.canouil.dev/pkg"\n' >"${SCRATCH}/quoted.yml"
out="$("${script}" "${SCRATCH}/quoted.yml" "")"
assert_eq '["no-release"]' "$(value matrix "${out}" | jq -c '[.include[].profile]')" "untagged profile"
assert_eq '[{"version":"dev","url":"https://m.canouil.dev/pkg/"}]' "$(value versions "${out}")" "untagged versions"

printf 'extensions:\n  atelier:\n    site-url: *site-url\nwebsite:\n  site-url: &site-url https://m.canouil.dev/pkg\n' >"${SCRATCH}/alias-first.yml"
out="$("${script}" "${SCRATCH}/alias-first.yml" "")"
assert_eq '"https://m.canouil.dev/pkg/"' "$(value versions "${out}" | jq -c '.[0].url')" "website site-url after an alias elsewhere"

printf 'website:\n  site-url: https://m.canouil.dev/pkg # the published URL\n' >"${SCRATCH}/comment.yml"
out="$("${script}" "${SCRATCH}/comment.yml" "")"
assert_eq '"https://m.canouil.dev/pkg/"' "$(value versions "${out}" | jq -c '.[0].url')" "inline comment"

printf 'website:\n  site-url: *elsewhere\n' >"${SCRATCH}/alias.yml"
status=0
err="$("${script}" "${SCRATCH}/alias.yml" "" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "alias site-url"
assert_contains "${err}" "website.site-url in ${SCRATCH}/alias.yml is an alias" "alias message"

printf 'website:\n  title: x\n' >"${SCRATCH}/missing.yml"
status=0
err="$("${script}" "${SCRATCH}/missing.yml" "1.2.0" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "missing site-url"
assert_contains "${err}" "site-url not found in ${SCRATCH}/missing.yml" "missing site-url message"
