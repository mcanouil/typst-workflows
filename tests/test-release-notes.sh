#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/release-notes/notes.sh"
changelog="${SCRATCH}/CHANGELOG.md"

cat >"${changelog}" <<'EOF'
# Changelog

## Unreleased

- feat: Next.

## 0.4.0 (2026-11-01)

## 0.2.0 (2026-10-01)

### Breaking changes

- feat!: Renamed.

### Other

- fix: Fixed. (#2)

## 0.1.0 (2026-09-01)

- feat: Initial release.
EOF

expected=$'### Breaking changes\n\n- feat!: Renamed.\n\n### Other\n\n- fix: Fixed. (#2)'
assert_eq "${expected}" "$("${script}" "${changelog}" 0.2.0)" "sub-sections kept, next release left out"
assert_eq "- feat: Initial release." "$("${script}" "${changelog}" 0.1.0)" "last section"

for version in 0.3.0 0.4.0 0.1; do
  status=0
  err="$("${script}" "${changelog}" "${version}" 2>&1 >/dev/null)" || status=$?
  assert_status 1 "${status}" "no notes for ${version}"
  assert_contains "${err}" "no notes under a '## ${version} (YYYY-MM-DD)' heading" "message for ${version}"
done
