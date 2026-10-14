#!/usr/bin/env bash
# Runs a command, keeps its output in a log, and writes a step summary.
set -euo pipefail

usage='usage: run-logged.sh <title> <log-file> -- <command> [args...]'
title="${1:?${usage}}"
log="${2:?${usage}}"
[[ "${3:-}" == "--" ]] || {
  echo "${usage}" >&2
  exit 2
}
shift 3

if [[ -z "${GITHUB_STEP_SUMMARY:-}" ]]; then
  echo "GITHUB_STEP_SUMMARY is not set; run this inside a workflow step or set it to a file." >&2
  exit 2
fi

status=0
"$@" 2>&1 | tee "${log}" || status=${PIPESTATUS[0]}

{
  echo "## ${title}"
  echo ""
  if [[ ${status} -eq 0 ]]; then
    echo "- Status: passed"
  else
    echo "- Status: failed (exit ${status})"
    echo ""
    echo "~~~~text"
    tail -n 40 "${log}"
    echo "~~~~"
  fi
} >>"${GITHUB_STEP_SUMMARY}"

exit "${status}"
