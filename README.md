# Typst Workflows

Reusable GitHub Actions workflows and actions for Typst packages.

This repository holds the CI that [gribouille](https://github.com/mcanouil/gribouille) and [keisen](https://github.com/mcanouil/keisen) share.
Each package keeps its own checks in its own scripts.
The workflows here only set up the tools and call those scripts, so a run on your machine and a run in CI do the same thing.

## Repository contract

A package that calls these workflows provides the files below.

| File | What the workflows expect |
| --- | --- |
| `typst.toml` | A `compiler` key, which sets the Typst version that CI installs. |
| `tools/check.sh` | The full local suite. It exits 0 when every check passes and 1 otherwise. It accepts extra arguments. |
| `tools/dry-release.sh` | Stages the package, installs it as `@preview/<name>:<version>`, compiles against that copy, and lints the payload with `typst-package-check`. It honours `XDG_DATA_HOME` and `STAGE_ROOT`. |
| `.editorconfig` | The indentation that shfmt reads. Keep it out of the published package with the `exclude` list in `typst.toml`. |

## Checks

`.github/workflows/checks.yml` runs three jobs:

- `suite` runs `tools/check.sh`.
- `package` installs `typst-package-check` and runs `tools/dry-release.sh`.
- `lint` runs shellcheck and shfmt over the package's shell scripts.

Every job skips a draft pull request.
Add `ready_for_review` to your `pull_request` types, so the checks run once the draft is lifted.

| Input | Type | Default | Use |
| --- | --- | --- | --- |
| `needs-lua` | boolean | `false` | Installs Lua 5.4 for the suite and the package job. |
| `needs-quarto` | boolean | `false` | Installs the current Quarto release for the suite. |
| `needs-imagemagick` | boolean | `false` | Installs ImageMagick for the suite, if the runner lacks it. |
| `check-args` | string | `""` | Extra arguments for `tools/check.sh`. |
| `failure-artifacts` | string | `""` | Paths, one per line, that the suite uploads when it fails. |
| `shellcheck-paths` | string | `tools/*.sh .github/scripts/*.sh docs/_scripts/*.sh` | Globs that shellcheck reads. |
| `shfmt-paths` | string | `tools/*.sh .github/scripts/*.sh` | Globs that shfmt reads. |

Each list of globs must match at least one file, or the lint job fails.
A glob that matches nothing usually means that a path moved.

Here's a minimal caller:

```yaml
name: Checks

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
  push:
    branches:
      - main

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}

jobs:
  checks:
    uses: mcanouil/typst-workflows/.github/workflows/checks.yml@v1
    with:
      needs-lua: true
```

The concurrency group cancels a superseded run on a pull request.
On `main`, every commit gets a group of its own, so each one keeps its result.

## Actions

The workflows are built from these composite actions, which you can also use on their own:

- `actions/setup-typst` reads `compiler` from `typst.toml` and installs that Typst.
- `actions/run-logged` runs a command and writes its status, and the end of its output on failure, to the step summary.
- `actions/lint-shell` installs shfmt and runs shellcheck and shfmt.
- `actions/setup-package-check` installs `typst-package-check`, cached by the upstream revision.

## Versioning

Call everything with `@v1`.
The `v1` tag moves to each compatible release, and every release also gets a fixed `v1.x.y` tag if you'd rather pin one.
A change that breaks callers starts `v2`.

## Development

Run the checks before you push:

```sh
actionlint
actions/lint-shell/lint-shell.sh "actions/*/*.sh tests/*.sh" "actions/*/*.sh tests/*.sh"
tests/run.sh
```

The tests need Bash 4.4 or newer, shellcheck and shfmt.

## Licence

MIT, see [LICENSE](LICENSE).
