---
name: lid-release
description: Drive Lid's tag-based self-signed GitHub Actions release. Use when Codex is asked to release, publish, ship, tag a version, update the appcast, update the Homebrew cask, or create a GitHub Release for Lid; this skill supports only the self-signed DMG workflow backed by GitHub Actions and qiyuey/homebrew-tap.
---

# Lid Release

## Overview

Use this skill to start Lid's self-signed release. The skill script prepares the version commit and pushes the release tag; GitHub Actions is the source of truth for building the DMG, creating the GitHub Release, updating Sparkle appcast, and publishing the Homebrew cask.

Production, Developer ID, notarized, and stapled releases are intentionally out of scope. Do not use `scripts/release.sh` for this skill.

## Script

Run from the repository root:

```bash
.agents/skills/lid-release/scripts/release-self-signed.sh
```

Useful variants:

```bash
.agents/skills/lid-release/scripts/release-self-signed.sh --dry-run
.agents/skills/lid-release/scripts/release-self-signed.sh --version 2026.7.3
.agents/skills/lid-release/scripts/release-self-signed.sh --no-watch
```

## Workflow

1. Treat invoking this skill as approval for a live self-signed GitHub release. Run `--dry-run` only when the user explicitly asks to preview, check, or dry-run without publishing.
2. Run the script from a clean `main` worktree. If the worktree is dirty, inspect the changes first: commit and push release-relevant changes before releasing, but stop and ask if unrelated local changes are present. Do not stash, revert, or hide local changes as part of release preparation.
3. Let the script sync `main`, bump `project.yml`, run `xcodegen generate`, run `Lid-CI`, commit and push the version bump, create tag `vYYYY.M.N`, push the tag, then watch `.github/workflows/release.yml`.
4. Let GitHub Actions build and verify the self-signed DMG, create/update the GitHub Release, generate and commit `docs/appcast.xml`, and update `qiyuey/homebrew-tap`.
5. After the workflow finishes, verify the release with `gh release view "$TAG"`, inspect the workflow result with `gh run view`, and verify Homebrew with `brew info --cask qiyuey/tap/lid` or the updated `qiyuey/homebrew-tap` `Casks/lid.rb`.
6. Report the release URL, commit hash, pushed tag, workflow URL/result, Homebrew tap update, test result, and any remaining tracked changes.

## Failure Handling

- If the script fails before the version bump commit, fix the issue and rerun.
- If it fails after pushing the tag, inspect `gh run list --workflow release.yml`, `gh release view v<version>`, `docs/appcast.xml`, and `qiyuey/homebrew-tap` before deciding whether to continue manually.
- Do not delete or overwrite an existing release unless the user explicitly asks for that recovery action.
- Do not roll back release commits automatically.
- If a tag-triggered workflow fails after creating a release asset, rerun the workflow or push a new version; avoid moving tags unless the user explicitly chooses that recovery path.

## Prerequisites

- GitHub CLI must be authenticated for `qiyuey/lid`.
- Local release preparation requires `xcodegen` and Xcode command line tools.
- GitHub Actions requires repository secrets: `LID_SELF_SIGNED_CERT_P12_BASE64`, `LID_SELF_SIGNED_CERT_PASSWORD`, `SPARKLE_ED_PRIVATE_KEY`, and `HOMEBREW_TAP_TOKEN`.
- The Homebrew tap is `qiyuey/homebrew-tap`, the same tap used by `bing-wallpaper-now`.
- The workflow reuses `scripts/package-self-signed-dmg.sh` for deterministic app/DMG signing and verification.
