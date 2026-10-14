#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/lint-shell/lint-shell.sh"
cp "${ROOT}/.editorconfig" "${SCRATCH}/.editorconfig"
mkdir -p "${SCRATCH}/tools"
printf '#!/usr/bin/env bash\nset -euo pipefail\necho "ok"\n' >"${SCRATCH}/tools/good.sh"

status=0
(cd "${SCRATCH}" && "${script}" "tools/*.sh" "tools/*.sh") >/dev/null || status=$?
assert_status 0 "${status}" "clean script"

status=0
err="$(cd "${SCRATCH}" && "${script}" "missing/*.sh" "tools/*.sh" 2>&1)" || status=$?
assert_status 1 "${status}" "empty shellcheck glob"
assert_contains "${err}" "nothing matched: missing/*.sh" "empty glob message"

printf '#!/usr/bin/env bash\nset -euo pipefail\nif true; then\necho "x"\nfi\n' >"${SCRATCH}/tools/bad.sh"
status=0
(cd "${SCRATCH}" && "${script}" "tools/*.sh" "tools/*.sh") >/dev/null 2>&1 || status=$?
assert_status 1 "${status}" "unformatted script"
