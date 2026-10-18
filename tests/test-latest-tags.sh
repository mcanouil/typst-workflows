#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/bump-pins/latest-tags.sh"

# A fake gh that answers from FAKE_TAGS ("owner/repo tag" lines) and fails for
# any other repository.
mkdir -p "${SCRATCH}/bin"
cat >"${SCRATCH}/bin/gh" <<'EOF'
#!/usr/bin/env bash
repo="${2#repos/}"
repo="${repo%/releases/latest}"
tag="$(awk -v r="${repo}" '$1 == r { print $2 }' <<<"${FAKE_TAGS}")"
if [[ -z "${tag}" ]]; then
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
fi
echo "${tag}"
EOF
chmod +x "${SCRATCH}/bin/gh"
export PATH="${SCRATCH}/bin:${PATH}"
export FAKE_TAGS=$'typst/typst v0.15.1\ncetz-package/cetz 0.5.3'
tab=$'\t'

packages='- name: cetz
  repository: cetz-package/cetz
  file: src/deps.typ'

out="$(PACKAGES="${packages}" "${script}" typst.toml)"
assert_eq "typst${tab}typst.toml${tab}typst/typst${tab}v0.15.1"$'\n'"cetz${tab}src/deps.typ${tab}cetz-package/cetz${tab}0.5.3" "${out}" "typst and cetz lines"

out="$(PACKAGES="" "${script}" typst.toml)"
assert_eq "typst${tab}typst.toml${tab}typst/typst${tab}v0.15.1" "${out}" "empty packages"

status=0
err="$(PACKAGES='- name: nope
  repository: someone/nope
  file: src/deps.typ' "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "lookup failure"
assert_contains "${err}" "could not read the latest release of someone/nope" "lookup failure message"

status=0
err="$(PACKAGES='name: cetz' "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "packages not a list"
assert_contains "${err}" "packages" "packages not a list message"

status=0
err="$(PACKAGES='- name: cetz
  file: src/deps.typ' "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "entry without repository"
assert_contains "${err}" "name, repository and file" "entry without repository message"
