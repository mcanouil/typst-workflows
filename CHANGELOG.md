# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

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
