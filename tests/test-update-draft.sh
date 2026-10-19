#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/update-draft/update-draft.sh"

mkdir -p "${SCRATCH}/bin" "${SCRATCH}/assets"
# A gh that logs one line per call. STUB_FAIL names a subcommand that fails.
cat >"${SCRATCH}/bin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${GH_LOG}"
if [[ "${2:-}" == "${STUB_FAIL:-}" ]]; then
  exit 1
fi
STUB
chmod +x "${SCRATCH}/bin/gh"
export GH_LOG="${SCRATCH}/gh.log"

printf 'Notes.\n' >"${SCRATCH}/notes.md"
touch "${SCRATCH}/assets/demo-0.2.0.tar.gz" "${SCRATCH}/assets/demo-0.2.0.zip"

run_script() {
  : >"${GH_LOG}"
  VERSION=0.2.0 NAME=demo SHA=abc123 NOTES="${SCRATCH}/notes.md" ASSETS_DIR="${SCRATCH}/assets" \
    PATH="${SCRATCH}/bin:${PATH}" "${script}" 2>"${SCRATCH}/err"
}

# The draft is moved to the commit, then the archives are replaced.
run_script
assert_eq "release edit 0.2.0 --target abc123 --notes-file ${SCRATCH}/notes.md" "$(sed -n 1p "${GH_LOG}")" "edit call"
assert_eq "release upload 0.2.0 --clobber ${SCRATCH}/assets/demo-0.2.0.tar.gz#demo 0.2.0 (tar.gz) ${SCRATCH}/assets/demo-0.2.0.zip#demo 0.2.0 (zip)" \
  "$(sed -n 2p "${GH_LOG}")" "upload call"
assert_eq 2 "$(wc -l <"${GH_LOG}" | tr -d ' ')" "call count"

# A failing edit stops the script and names the version.
set +e
STUB_FAIL=edit run_script
status=$?
set -e
if [[ ${status} -eq 0 ]]; then
  echo "  failing edit: expected a non-zero exit" >&2
  exit 1
fi
assert_contains "$(cat "${SCRATCH}/err")" "0.2.0" "failing edit names the version"
assert_eq 1 "$(wc -l <"${GH_LOG}" | tr -d ' ')" "no upload after a failed edit"

# A missing archive fails before gh is called.
rm "${SCRATCH}/assets/demo-0.2.0.zip"
set +e
run_script
status=$?
set -e
if [[ ${status} -eq 0 ]]; then
  echo "  missing archive: expected a non-zero exit" >&2
  exit 1
fi
assert_contains "$(cat "${SCRATCH}/err")" "demo-0.2.0.zip" "missing archive is named"
assert_eq 0 "$(wc -c <"${GH_LOG}" | tr -d ' ')" "gh is not called"
