#!/usr/bin/env bash
# Submits a package archive to Typst Universe. It commits the package on a
# branch made from typst/packages main, pushes the branch to a fork, and opens
# the pull request on typst/packages, or reuses the open one.
#
# Usage:
#   submit.sh --name <name> --version <x.y.z> --archive <name-x.y.z.tar.gz>
#             --description <universe.md> --fork <owner/repo>
#             [--pr=<number>] [--sync] [--dry-run]
#
#   --sync     Bring the main branch of the fork up to typst/packages main
#              first, so that the push does not need commits the fork lacks.
#   --pr=<n>   Reuse the head branch of the open pull request <n> and edit it.
#   --dry-run  Commit, and run `git push --dry-run`, which checks that the fork
#              takes the push. Then print the pull request body. Nothing is
#              pushed and no pull request is opened.
#
# The description file holds the paragraph for the pull request. A line that
# starts with `Name:` explains the package name, which typst/packages asks of a
# new package.
#
# Environment:
#   FORK_TOKEN    Syncs and pushes to the fork. When unset, Git and gh use their own login.
#   GH_TOKEN      Opens or edits the pull request on typst/packages.
#   UPSTREAM_URL  Where to clone typst/packages from.
#   FORK_URL      Where to push the branch.
#
# Prints `branch=<branch>`, and `pr_url=<url>` unless --dry-run, on stdout.
set -euo pipefail

die() {
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    printf '::error::%s\n' "$*" >&2
  else
    printf 'submit: %s\n' "$*" >&2
  fi
  exit 1
}

log() {
  printf '%s\n' "$*" >&2
}

name=""
version=""
archive=""
description=""
fork=""
pr=""
sync=0
dry_run=0
while [[ $# -gt 0 ]]; do
  case "$1" in
  --name | --version | --archive | --description | --fork)
    [[ $# -ge 2 && -n "$2" ]] || die "$1 needs a value."
    case "$1" in
    --name) name="$2" ;;
    --version) version="$2" ;;
    --archive) archive="$2" ;;
    --description) description="$2" ;;
    --fork) fork="$2" ;;
    esac
    shift 2
    ;;
  --pr=*)
    pr="${1#--pr=}"
    shift
    ;;
  --sync)
    sync=1
    shift
    ;;
  --dry-run)
    dry_run=1
    shift
    ;;
  -h | --help)
    sed -n '2,/^set -euo pipefail/{/^set /d;s/^# \{0,1\}//;p;}' "$0"
    exit 0
    ;;
  *) die "unknown argument '$1'. Run submit.sh --help." ;;
  esac
done

for required in name version archive description fork; do
  [[ -n "${!required}" ]] || die "--${required} is required. Run submit.sh --help."
done
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "--version must be x.y.z; got '${version}'."
[[ "${fork}" == */* ]] || die "--fork must be owner/repo; got '${fork}'."
[[ -z "${pr}" || "${pr}" =~ ^[0-9]+$ ]] || die "--pr must be a pull request number; got '${pr}'."
[[ -f "${archive}" ]] || die "${archive} does not exist."
[[ -f "${description}" ]] || die "${description} does not exist. Write the package paragraph for the pull request there."

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# --- The payload: the archive, with one root directory, <name>-<version>.
tar -xzf "${archive}" -C "${tmp}"
payload="${tmp}/${name}-${version}"
[[ -d "${payload}" ]] || die "${archive} has no ${name}-${version}/ root directory. Build it with tools/package.sh archive."
manifest_field() {
  awk -F'"' -v key="$1" '$0 ~ "^" key "[[:space:]]*=" { print $2; exit }' "${payload}/typst.toml"
}
found="$(manifest_field name):$(manifest_field version)"
[[ "${found}" == "${name}:${version}" ]] || die "the typst.toml in ${archive} names ${found}, not ${name}:${version}."
repository="$(manifest_field repository)"
homepage="$(manifest_field homepage)"

# --- The description, and the naming explanation for a new package.
summary="$(grep -v '^Name:' "${description}" | sed '/^[[:space:]]*$/d' | paste -sd ' ' -)"
naming="$(sed -n 's/^Name:[[:space:]]*//p' "${description}" | head -n 1)"
[[ -n "${summary}" ]] || die "${description} holds no description paragraph."

fork_owner="${fork%%/*}"
upstream_url="${UPSTREAM_URL:-https://github.com/typst/packages.git}"
if [[ -n "${FORK_URL:-}" ]]; then
  fork_url="${FORK_URL}"
elif [[ -n "${FORK_TOKEN:-}" ]]; then
  fork_url="https://x-access-token:${FORK_TOKEN}@github.com/${fork}.git"
else
  fork_url="https://github.com/${fork}.git"
fi
package_dir="packages/preview/${name}"

# --- Sync: the clone below is shallow, so the fork must hold its parent commit.
if [[ ${sync} -eq 1 ]]; then
  GH_TOKEN="${FORK_TOKEN:-${GH_TOKEN:-}}" gh api --method POST "repos/${fork}/merge-upstream" -f branch=main >/dev/null ||
    die "could not bring ${fork} up to typst/packages main. If its main holds commits of its own, reset it to upstream. If an upstream commit touches .github/workflows, give the token the Workflows permission."
  log "Synced ${fork} with typst/packages main."
fi

# --- The branch: a fresh one per version, or the head of the pull request to reuse.
if [[ -n "${pr}" ]]; then
  IFS=$'\t' read -r pr_state pr_head pr_owner < <(gh pr view "${pr}" --repo typst/packages \
    --json state,headRefName,headRepositoryOwner \
    --jq '[.state, .headRefName, .headRepositoryOwner.login] | @tsv')
  [[ "${pr_state}" == "OPEN" ]] || die "typst/packages#${pr} is ${pr_state}. Drop --pr to open a new pull request."
  [[ "${pr_owner}" == "${fork_owner}" ]] || die "typst/packages#${pr} comes from ${pr_owner}, not from ${fork_owner}."
  branch="${pr_head}"
else
  branch="${name}-${version}"
fi

# --- A sparse, blobless, shallow clone of typst/packages: only this package.
clone="${tmp}/packages"
git clone --quiet --filter=blob:none --depth 1 --no-checkout --branch main "${upstream_url}" "${clone}"
git -C "${clone}" sparse-checkout set "${package_dir}"
git -C "${clone}" checkout --quiet -B "${branch}" origin/main

if git -C "${clone}" cat-file -e "origin/main:${package_dir}/${version}" 2>/dev/null; then
  die "${name}:${version} is already on typst/packages main, so there is nothing to submit."
fi
if git -C "${clone}" cat-file -e "origin/main:${package_dir}" 2>/dev/null; then
  update=1
else
  update=0
fi
if [[ ${update} -eq 0 && -z "${naming}" ]]; then
  die "${name} is a new package: add a line that starts with 'Name:' to ${description}, to explain the name, as the typst/packages checklist asks."
fi

mkdir -p "${clone}/${package_dir}"
cp -R "${payload}" "${clone}/${package_dir}/${version}"
git -C "${clone}" add "${package_dir}/${version}"
git -C "${clone}" commit --quiet -m "${name}:${version}"
git -C "${clone}" remote add fork "${fork_url}"

# --- The pull request body, after the typst/packages template.
body="${tmp}/body.md"
{
  printf 'I am submitting\n'
  if [[ ${update} -eq 1 ]]; then
    printf -- '- [ ] a new package\n- [x] an update for a package\n'
  else
    printf -- '- [x] a new package\n- [ ] an update for a package\n'
  fi
  printf '\nDescription: %s\n\n' "${summary}"
  printf -- '- Repository: %s\n' "${repository}"
  printf -- '- Release: %s/releases/tag/%s\n' "${repository}" "${version}"
  printf -- '- Homepage: %s\n' "${homepage}"
  if [[ ${update} -eq 0 ]]; then
    printf '\nI have read and followed the submission guidelines and, in particular, I\n'
    printf -- '- [x] selected [a name](https://github.com/typst/packages/blob/main/docs/manifest.md#naming-rules) that is not the most obvious or canonical name for what the package does\n'
    printf -- '  - Explanation: %s\n' "${naming}"
    # shellcheck disable=SC2016 # the backticks are Markdown, not a command
    printf -- '- [x] added a [`typst.toml`](https://github.com/typst/packages/blob/main/docs/manifest.md#package-metadata) file with all required keys\n'
    # shellcheck disable=SC2016 # the backticks are Markdown, not a command
    printf -- '- [x] added a [`README.md`](https://github.com/typst/packages/blob/main/docs/documentation.md) with documentation for my package\n'
    # shellcheck disable=SC2016 # the backticks are Markdown, not a command
    printf -- '- [x] have chosen [a license](https://github.com/typst/packages/blob/main/docs/licensing.md) and added a `LICENSE` file or linked one in my `README.md`\n'
    printf -- '- [x] tested my package locally on my system and it worked\n'
    # shellcheck disable=SC2016 # the backticks are Markdown, not a command
    printf -- '- [x] [`exclude`d](https://github.com/typst/packages/blob/main/docs/tips.md#what-to-commit-what-to-exclude) PDFs or README images, if any, but not the LICENSE\n'
  fi
} >"${body}"

printf 'branch=%s\n' "${branch}"

if [[ ${dry_run} -eq 1 ]]; then
  git -C "${clone}" push --quiet --dry-run --force fork "${branch}" ||
    die "${fork} refused a dry-run push of ${branch}. Check that the token can write to it."
  log "[dry-run] ${name}:${version} is committed on ${branch}. Nothing was pushed and no pull request was opened."
  git -C "${clone}" show --stat --format='%s' HEAD >&2
  log "[dry-run] Pull request title: ${name}:${version}"
  log "[dry-run] Pull request body:"
  cat "${body}" >&2
  exit 0
fi

# A run for the same version replaces the branch, which updates its pull request.
git -C "${clone}" push --quiet --force fork "${branch}" ||
  die "${fork} refused the push of ${branch}. Check that the token can write to it, and that --sync ran."

if [[ -n "${pr}" ]]; then
  gh pr edit "${pr}" --repo typst/packages --title "${name}:${version}" --body-file "${body}" >&2
  pr_url="$(gh pr view "${pr}" --repo typst/packages --json url --jq .url)"
else
  # --head takes a bare branch name here, so the owner is matched apart.
  pr_url="$(gh pr list --repo typst/packages --head "${branch}" --state open \
    --json url,headRepositoryOwner \
    --jq "[.[] | select(.headRepositoryOwner.login == \"${fork_owner}\")][0].url // empty")"
  if [[ -n "${pr_url}" ]]; then
    log "Reusing the open pull request ${pr_url}; the push updated it."
  else
    pr_url="$(gh pr create --repo typst/packages --base main \
      --head "${fork_owner}:${branch}" --title "${name}:${version}" --body-file "${body}")"
  fi
fi
printf 'pr_url=%s\n' "${pr_url}"
