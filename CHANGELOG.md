# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- fix: The `days` input of the lock-closed workflow is a string, so a caller can pass a dispatched number input to it. (#20)

## 2.5.1 (2026-10-21)

- fix: The lock-closed workflow asks for no repository permission at the top level, so a caller that grants only issues and pull requests can call it. (#19)

## 2.5.0 (2026-10-21)

- feat: Add the lock-closed reusable workflow, which locks closed issues and pull requests after a number of days with no activity. (#18)

## 2.4.1 (2026-10-20)

- refactor: Call the update-draft script directly, and pass the targets input straight to both bump steps. (#17)

## 2.4.0 (2026-10-19)

- refactor: Write typst.toml and CITATION.cff through the release-actions presets; callers list only their extra files. (#16)

## 2.3.1 (2026-10-19)

- refactor: Move the update of an existing draft into the update-draft action, with tests. (#15)

## 2.3.0 (2026-10-18)

- feat: Add the snapshot-refresh reusable workflow, which regenerates the visual goldens and lands them. (#14)
- feat: Add the dependency-update reusable workflow, which follows Typst and the listed packages and opens one pull request. (#14)

## 2.2.0 (2026-10-17)

- refactor: Rely on release-actions v1.3.0 for the App check and `after-bump`, and drop the steps that did this in the workflows. (#13)
- feat: The release commit now includes the files that `after-bump` creates, except files that `.gitignore` matches. Before, it included only tracked files. (#13)

## 2.1.0 (2026-10-17)

- refactor: Get tokens from the release-actions `token` action and push the version with its `land` action.
  The release commit is now `ci: release X [skip ci]`. (#12)
- refactor: Remove the `setup-git-user` action, which no workflow uses any more.
  The release-actions `token` action sets the same identity. (#12)

## 2.0.1 (2026-10-16)

- fix: The Typst Universe job fills the Typst package cache before it lints the archive, so a package with dependencies no longer fails there. (#9)

## 2.0.0 (2026-10-15)

- feat!: The Release workflow takes a `targets` input and bumps the version with mcanouil/release-actions, so a package no longer provides `tools/bump-version.sh`. (#8)
- feat!: Remove the `release-notes` action; use `mcanouil/release-actions/notes` instead. (#8)
- feat: The Release workflow takes an `after-bump` command, run after the bump and before the commit. (#8)

## 1.3.0 (2026-10-15)

- feat: Release notes now come from the changelog. (#7)

## 1.2.0 (2026-10-15)

- feat: Add the release and Typst Universe actions. (#4)
- feat: Add the reusable release and publish workflows. (#5)

## 1.1.0 (2026-10-14)

- feat: Add the reusable docs workflow. (#2)

## 1.0.0 (2026-10-14)

- feat: Initial release.
