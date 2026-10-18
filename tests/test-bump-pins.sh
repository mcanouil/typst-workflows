#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091 # tests/lib.sh is linted as a file of its own.
source "${ROOT}/tests/lib.sh"

script="${ROOT}/actions/bump-pins/bump-pins.sh"

value() {
  sed -n "s/^$1=//p" <<<"$2"
}

block() {
  awk -v name="$1" '
    $0 == name "<<EOF" { inside = 1; next }
    inside && $0 == "EOF" { inside = 0; next }
    inside
  ' <<<"$2"
}

work="${SCRATCH}/repo"
mkdir -p "${work}/src"
cd "${work}"

reset() {
  printf '[package]\nname = "demo"\ncompiler = "0.15.0"\n' >typst.toml
  printf '#import "@preview/cetz:0.5.2"\n// Again: #import "@preview/cetz:0.5.2": draw\n' >src/deps.typ
}

# Typst only, with a leading v on the tag.
reset
out="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.1\n' | "${script}" typst.toml)"
assert_contains "$(cat typst.toml)" 'compiler = "0.15.1"' "typst bumped"
assert_eq "true" "$(value any "${out}")" "typst any"
assert_eq "ci: bump typst to 0.15.1" "$(value subject "${out}")" "typst subject"
assert_eq "typst.toml" "$(block files "${out}")" "typst files"
assert_contains "$(block body "${out}")" "- typst 0.15.0 to 0.15.1 (https://github.com/typst/typst/releases/tag/v0.15.1)" "typst body"

# Typst and a package pinned twice, tag without a v.
reset
out="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.1\ncetz\tsrc/deps.typ\tcetz-package/cetz\t0.5.3\n' | "${script}" typst.toml)"
assert_eq "2" "$(grep -c '@preview/cetz:0.5.3' src/deps.typ)" "both cetz pins bumped"
assert_eq "ci: bump typst to 0.15.1, cetz to 0.5.3" "$(value subject "${out}")" "two subject"
assert_eq $'typst.toml\nsrc/deps.typ' "$(block files "${out}")" "two files"
assert_contains "$(block body "${out}")" "- cetz 0.5.2 to 0.5.3 (https://github.com/cetz-package/cetz/releases/tag/0.5.3)" "cetz body"

# Nothing moved.
reset
before="$(cksum typst.toml src/deps.typ)"
out="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.0\ncetz\tsrc/deps.typ\tcetz-package/cetz\tv0.5.2\n' | "${script}" typst.toml)"
assert_eq "false" "$(value any "${out}")" "no move any"
assert_eq "${before}" "$(cksum typst.toml src/deps.typ)" "no move leaves files"

# Missing compiler key.
printf '[package]\nname = "demo"\n' >typst.toml
status=0
err="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.1\n' | "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "missing compiler"
assert_contains "${err}" "compiler not found in typst.toml" "missing compiler message"

# Missing package pin.
reset
printf '// no imports\n' >src/deps.typ
status=0
err="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.0\ncetz\tsrc/deps.typ\tcetz-package/cetz\t0.5.3\n' | "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "missing pin"
assert_contains "${err}" "@preview/cetz" "missing pin names the package"
assert_contains "${err}" "src/deps.typ" "missing pin names the file"

# A tag that is not a version.
reset
status=0
err="$(printf 'typst\ttypst.toml\ttypst/typst\tnightly\n' | "${script}" typst.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "tag not a version"
assert_contains "${err}" "nightly" "tag not a version names the tag"
assert_contains "$(cat typst.toml)" 'compiler = "0.15.0"' "tag not a version leaves the manifest"

# No manifest.
status=0
err="$(printf 'typst\tmissing.toml\ttypst/typst\tv0.15.1\n' | "${script}" missing.toml 2>&1 >/dev/null)" || status=$?
assert_status 1 "${status}" "missing manifest"
assert_contains "${err}" "manifest not found: missing.toml" "missing manifest message"

# A pin above the latest release is left alone.
reset
printf '[package]\nname = "demo"\ncompiler = "0.16.0-rc1"\n' >typst.toml
out="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.1\n' | "${script}" typst.toml)"
assert_eq "false" "$(value any "${out}")" "no downgrade any"
assert_contains "$(cat typst.toml)" 'compiler = "0.16.0-rc1"' "no downgrade keeps the pin"

# Two packages pinned in one file list that file once.
reset
printf '#import "@preview/cetz:0.5.2"\n#import "@preview/cetz-plot:0.1.2"\n' >src/deps.typ
out="$(printf 'typst\ttypst.toml\ttypst/typst\tv0.15.0\ncetz\tsrc/deps.typ\tcetz-package/cetz\t0.5.3\ncetz-plot\tsrc/deps.typ\tcetz-package/cetz-plot\t0.1.3\n' | "${script}" typst.toml)"
assert_eq "src/deps.typ" "$(block files "${out}")" "shared file listed once"
assert_contains "$(cat src/deps.typ)" "@preview/cetz-plot:0.1.3" "second package in the shared file"
