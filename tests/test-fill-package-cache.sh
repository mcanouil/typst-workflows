#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/fill-package-cache/fill.sh"

# A typst stub that records each compile and fails when STUB_FAIL names the source.
mkdir -p "${SCRATCH}/bin"
cat >"${SCRATCH}/bin/typst" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"${STUB_LOG}"
[[ "${STUB_FAIL:-}" == "" || "$*" != *"${STUB_FAIL}"* ]]
EOF
chmod +x "${SCRATCH}/bin/typst"

package="${SCRATCH}/demo/0.1.0"
mkdir -p "${package}/template"
printf '[package]\nname = "demo"\nversion = "0.1.0"\nentrypoint = "lib.typ"\n' >"${package}/typst.toml"

fill() {
  : >"${SCRATCH}/log"
  STUB_LOG="${SCRATCH}/log" PATH="${SCRATCH}/bin:${PATH}" "${script}" "${package}" demo 0.1.0 "${SCRATCH}/work-$1"
}

fill plain
assert_eq 1 "$(wc -l <"${SCRATCH}/log" | tr -d ' ')" "a package with no template compiles once"
assert_contains "$(cat "${SCRATCH}/log")" "--package-path ${SCRATCH}/work-plain/packages" "the probe resolves the package locally"
assert_eq '#import "@preview/demo:0.1.0": *' "$(cat "${SCRATCH}/work-plain/probe.typ")" "the probe imports the package"
assert_eq "$(cd "${package}" && pwd -P)" "$(cd "${SCRATCH}/work-plain/packages/preview/demo/0.1.0" && pwd -P)" "the package is linked under its version"

printf '\n[template]\npath = "template"\nentrypoint = "main.typ"\n' >>"${package}/typst.toml"
fill template
assert_eq 2 "$(wc -l <"${SCRATCH}/log" | tr -d ' ')" "a package with a template compiles twice"
assert_contains "$(tail -n 1 "${SCRATCH}/log")" "${package}/template/main.typ" "the template entrypoint is compiled"

status=0
err="$(STUB_FAIL=main.typ fill failing 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "a compile failure stops the fill"
assert_contains "${err}" "could not compile ${package}/template/main.typ" "the failure names the source"
