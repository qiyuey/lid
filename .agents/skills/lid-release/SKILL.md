---
name: lid-release
description: Publish Lid's self-signed GitHub/Sparkle release from the local repository. Use when Codex is asked to release, publish, ship, tag, update the appcast, or create a GitHub Release for Lid; this skill supports only the self-signed DMG workflow.
---

# Lid Release

## Overview

Use this skill to publish Lid's self-signed release. The release script is the source of truth; do not hand-run the steps unless the script fails and you are continuing from the exact failed step.

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
```

## Workflow

1. Confirm the user wants a live self-signed GitHub release. If they ask to preview, run `--dry-run`.
2. Run the script from a clean `main` worktree. Let it compute the next `YYYY.M.N` version unless the user specified one.
3. Let the script perform the whole release: sync `main`, bump `project.yml`, run `xcodegen generate`, run `Lid-CI`, commit and push the version bump, build the self-signed DMG, create the GitHub Release, generate `docs/appcast.xml`, commit and push the appcast, then verify release/tag/main.
4. Report the release URL, commit hashes, pushed branch, test result, DMG path, and any remaining tracked changes.

## Failure Handling

- If the script fails before the version bump commit, fix the issue and rerun.
- If it fails after the version bump commit or after creating the GitHub Release, inspect `git status`, `gh release view v<version>`, `docs/appcast.xml`, and the DMG path before deciding whether to continue manually.
- Do not delete or overwrite an existing release unless the user explicitly asks for that recovery action.
- Do not roll back release commits automatically.

## Prerequisites

- GitHub CLI must be authenticated for `qiyuey/lid`.
- `xcodegen`, Xcode command line tools, and Sparkle `generate_appcast` must be available.
- Sparkle private key account defaults to `qiyuey-lid`; override with `SPARKLE_ACCOUNT` only when needed.
- The script reuses `scripts/package-self-signed-dmg.sh` for deterministic app/DMG signing and verification.
