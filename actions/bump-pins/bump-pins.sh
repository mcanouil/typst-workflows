#!/usr/bin/env bash
# Moves the Typst compiler and @preview package pins to their latest releases.
#
#   bump-pins.sh <typst.toml>
#
# Standard input holds one line per dependency, tab-separated:
#   name  file  repository  tag
# The line named typst is the compiler key of <typst.toml>; every other line
# is the @preview/<name>:<version> import in <file>. A leading v on the tag is
# dropped. Standard output takes the lines of GITHUB_OUTPUT: any, subject,
# body and files.
set -euo pipefail

manifest="${1:?usage: bump-pins.sh <typst.toml>}"

version_re='[0-9][0-9A-Za-z.+-]*'
subject_parts=()
body_lines=()
changed=()

while IFS=$'\t' read -r name file repository tag; do
  [[ -n "${name}" ]] || continue
  latest="${tag#v}"
  if [[ ! "${latest}" =~ ^[0-9][0-9A-Za-z.+-]*$ ]]; then
    printf 'the latest release of %s has the tag %s, which is not a version. Pin %s by hand.\n' "${repository}" "${tag}" "${name}" >&2
    exit 1
  fi
  if [[ "${name}" == "typst" ]]; then
    current="$(awk -F'"' '/^compiler[[:space:]]*=/ { print $2; exit }' "${manifest}")"
    if [[ -z "${current}" ]]; then
      printf 'compiler not found in %s. Add compiler = "X.Y.Z" under [package].\n' "${manifest}" >&2
      exit 1
    fi
  else
    current="$(grep -oE "@preview/${name}:${version_re}" "${file}" 2>/dev/null | head -n 1 | cut -d: -f2 || true)"
    if [[ -z "${current}" ]]; then
      printf 'no @preview/%s pin found in %s. Fix the file in the packages input, or import the package there.\n' "${name}" "${file}" >&2
      exit 1
    fi
  fi
  [[ "${current}" != "${latest}" ]] || continue

  if [[ "${name}" == "typst" ]]; then
    LATEST="${latest}" perl -pi -e 's/^(compiler\s*=\s*")[^"]+/${1}$ENV{LATEST}/' "${manifest}"
  else
    NAME="${name}" LATEST="${latest}" perl -pi -e 's/(\@preview\/\Q$ENV{NAME}\E:)[0-9][0-9A-Za-z.+-]*/${1}$ENV{LATEST}/g' "${file}"
  fi
  subject_parts+=("${name} to ${latest}")
  body_lines+=("- ${name} ${current} to ${latest} (https://github.com/${repository}/releases/tag/${tag})")
  changed+=("${file}")
done

if [[ ${#subject_parts[@]} -eq 0 ]]; then
  echo "any=false"
  exit 0
fi

subject="ci: bump ${subject_parts[0]}"
for part in "${subject_parts[@]:1}"; do
  subject+=", ${part}"
done

echo "any=true"
echo "subject=${subject}"
echo "body<<EOF"
echo "Automated bump of the Typst toolchain dependencies."
echo
printf '%s\n' "${body_lines[@]}"
echo "EOF"
echo "files<<EOF"
printf '%s\n' "${changed[@]}" | awk '!seen[$0]++'
echo "EOF"
