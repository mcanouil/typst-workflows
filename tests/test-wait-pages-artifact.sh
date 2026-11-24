#!/usr/bin/env bash
set -euo pipefail

node --test "${ROOT}/tests/wait-pages-artifact.test.js"
