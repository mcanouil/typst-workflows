#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/universe-submit/submit.sh"

# A neutral Git: no signing or hooks from the machine running the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# typst/packages holds demo 0.1.0 and other 1.0.0. The fork is a copy of it.
upstream="${SCRATCH}/upstream"
git init -q -b main "${upstream}"
for package in demo/0.1.0 other/1.0.0; do
  mkdir -p "${upstream}/packages/preview/${package}"
  printf '#let x = 1\n' >"${upstream}/packages/preview/${package}/lib.typ"
done
git -C "${upstream}" add -A
git -C "${upstream}" commit -q -m "initial"
git -C "${upstream}" config uploadpack.allowFilter true
fork="${SCRATCH}/fork.git"
git clone -q --bare "${upstream}" "${fork}"
export UPSTREAM_URL="file://${upstream}" FORK_URL="file://${fork}"

# make_archive <name> <version> [manifest version]
make_archive() {
  local payload="${SCRATCH}/build/$1-$2"
  mkdir -p "${payload}"
  printf '[package]\nname = "%s"\nversion = "%s"\nrepository = "https://github.com/o/%s"\nhomepage = "https://o.dev/%s"\n' \
    "$1" "${3:-$2}" "$1" "$1" >"${payload}/typst.toml"
  printf '#let x = 1\n' >"${payload}/lib.typ"
  tar -czf "${SCRATCH}/$1-$2.tar.gz" -C "${SCRATCH}/build" "$1-$2"
}

printf 'Demo draws things.\n' >"${SCRATCH}/update.md"
printf 'Fresh draws other things.\n\nName: Fresh is a made-up word.\n' >"${SCRATCH}/new.md"
printf '### Breaking changes\n\n- feat!: Renamed a thing. (#7)\n' >"${SCRATCH}/notes.md"

submit() {
  "${script}" --fork o/fork --dry-run "$@"
}

# An update of a package that typst/packages already has, with its notes.
make_archive demo 0.2.0
out="$(submit --name demo --version 0.2.0 --archive "${SCRATCH}/demo-0.2.0.tar.gz" \
  --description "${SCRATCH}/update.md" --notes "${SCRATCH}/notes.md" 2>"${SCRATCH}/err")"
err="$(cat "${SCRATCH}/err")"
assert_eq "branch=demo-0.2.0" "${out}" "update branch"
assert_contains "${err}" "- [x] an update for a package" "update box"
assert_contains "${err}" "Description: Demo draws things." "update description"
assert_contains "${err}" $'Changes in 0.2.0:\n\n### Breaking changes\n\n- feat!: Renamed a thing. (#7)' "release notes"
assert_contains "${err}" "- Homepage: https://o.dev/demo" "homepage link"
# The GitHub Release is a draft until typst/packages merges, so its page is a 404.
if [[ "${err}" == *"/releases/tag/"* ]]; then
  echo "  update body: links the release page, which is a draft until the merge" >&2
  exit 1
fi
assert_contains "${err}" "packages/preview/demo/0.2.0/lib.typ" "staged file"
if [[ "${err}" == *"Explanation"* ]]; then
  echo "  update body: holds the new-package checklist" >&2
  exit 1
fi
status=0
git -C "${fork}" rev-parse -q --verify refs/heads/demo-0.2.0 >/dev/null || status=$?
assert_status 1 "${status}" "a dry run pushes nothing"

# A new package, with the naming explanation that the checklist asks for.
make_archive fresh 0.1.0
out="$(submit --name fresh --version 0.1.0 --archive "${SCRATCH}/fresh-0.1.0.tar.gz" \
  --description "${SCRATCH}/new.md" 2>"${SCRATCH}/err")"
err="$(cat "${SCRATCH}/err")"
assert_eq "branch=fresh-0.1.0" "${out}" "new branch"
assert_contains "${err}" "- [x] a new package" "new box"
assert_contains "${err}" "Description: Fresh draws other things." "new description without the Name line"
assert_contains "${err}" "  - Explanation: Fresh is a made-up word." "naming explanation"

# A new package without the explanation stops before any push.
status=0
err="$(submit --name fresh --version 0.1.0 --archive "${SCRATCH}/fresh-0.1.0.tar.gz" \
  --description "${SCRATCH}/update.md" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "new package without Name"
assert_contains "${err}" "add a line that starts with 'Name:'" "new package without Name message"

# A version that typst/packages already has.
make_archive demo 0.1.0
status=0
err="$(submit --name demo --version 0.1.0 --archive "${SCRATCH}/demo-0.1.0.tar.gz" \
  --description "${SCRATCH}/update.md" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "version already upstream"
assert_contains "${err}" "demo:0.1.0 is already on typst/packages" "version already upstream message"

# An archive whose manifest names another version.
make_archive demo 0.3.0 0.3.1
status=0
err="$(submit --name demo --version 0.3.0 --archive "${SCRATCH}/demo-0.3.0.tar.gz" \
  --description "${SCRATCH}/update.md" 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "manifest mismatch"
assert_contains "${err}" "names demo:0.3.1, not demo:0.3.0" "manifest mismatch message"

# --pr reuses the head branch of an open pull request from the fork owner.
mkdir -p "${SCRATCH}/bin"
cat >"${SCRATCH}/bin/gh" <<'EOF'
#!/usr/bin/env bash
printf '%s\t%s\t%s\n' "${STUB_STATE}" demo-review-fix o
EOF
chmod +x "${SCRATCH}/bin/gh"
out="$(STUB_STATE=OPEN PATH="${SCRATCH}/bin:${PATH}" submit --name demo --version 0.2.0 \
  --archive "${SCRATCH}/demo-0.2.0.tar.gz" --description "${SCRATCH}/update.md" --pr=42 2>/dev/null)"
assert_eq "branch=demo-review-fix" "${out}" "branch of the reused pull request"

status=0
err="$(STUB_STATE=CLOSED PATH="${SCRATCH}/bin:${PATH}" submit --name demo --version 0.2.0 \
  --archive "${SCRATCH}/demo-0.2.0.tar.gz" --description "${SCRATCH}/update.md" --pr=42 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "closed pull request"
assert_contains "${err}" "typst/packages#42 is CLOSED" "closed pull request message"
