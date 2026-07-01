# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

A tiny macOS menu-bar app that keeps your Mac running even when the lid is
closed. It is built for long-running coding agents, downloads, builds, and
remote sessions that should continue while your MacBook is tucked away.

> Lid is qiyuey's personal build for local use and experiments. Upstream
> copyright and the original MIT License are preserved where applicable.

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid menu bar popover with lid sleep prevention, safety controls, and battery status" width="420">
</p>

## Download

Get the latest signed macOS build from
[GitHub Releases](https://github.com/qiyuey/lid/releases).

If macOS says the app is damaged or cannot be opened, clear the quarantine
attribute after installing:

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## Why Lid

- **Lid sleep prevention**: one menu-bar switch keeps work running after the
  lid closes.
- **No repeated password prompts**: an optional privileged helper toggles the
  system flag over XPC.
- **Watchdog restore**: by default, the helper restores normal sleep if Lid
  quits or crashes.
- **Explicit persistence**: enable **Continue after quit** only when you want
  lid sleep prevention to stay active after exiting the app.
- **Safety guards**: pause on high thermal state, require charging, and stop at
  a low-battery cutoff.
- **Auto-off timer**: return to normal lid-close sleep after 15 minutes to
  4 hours.
- **Automatic updates**: Sparkle checks signed releases in the background.
- **Language control**: follow the system language, or choose English or
  Chinese manually.

## How It Works

macOS normally sleeps when a MacBook lid closes. On Apple Silicon, the reliable
way to override that is the `SleepDisabled` flag in `IOPMrootDomain`, the same
flag changed by:

```bash
sudo pmset -a disablesleep 1
```

`caffeinate` does not prevent lid-close sleep. Lid uses a root helper registered
with `SMAppService` to flip `SleepDisabled` without asking for an administrator
password every time. While lid sleep prevention is active, the app sends a
heartbeat to the helper; if the heartbeat stops and **Continue after quit** is
off, the helper restores normal sleep.

## Build

Lid is a SwiftUI menu-bar app generated with XcodeGen. `project.yml` is the
source of truth.

```bash
xcodegen generate
xcodebuild test -scheme Lid-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

Main directories:

- `Sources/Lid`: SwiftUI app, settings, onboarding, updater, helper lifecycle.
- `Sources/Helper`: privileged root helper registered through `SMAppService`.
- `Sources/Shared`: pure logic shared by the app, helper, and tests.
- `Tests/LidTests`: XCTest coverage for parsers, safety policy, settings, and
  helper identity.
- `Resources/Assets.xcassets`: app icon and menu-bar template images.
- `scripts`: release automation, Sparkle tooling, and helper scripts.

## Release

Release versions use `YYYY.M.N`, for example `2026.7.1`. Keep
`MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` equal.

Signed and notarized release builds require a Developer ID certificate,
notarytool credentials, and a Sparkle EdDSA signing key:

```bash
./scripts/release.sh
```

The script builds a DMG, notarizes and staples it, publishes a GitHub Release,
and writes the Sparkle appcast to `docs/appcast.xml`.

## Safety

Running a MacBook closed under heavy load can increase heat and drain battery.
Keep the machine plugged in and ventilated. Lid's safety controls reduce risk,
and a reboot always resets the underlying `SleepDisabled` flag.

To report a security issue, see [SECURITY.md](SECURITY.md).

## License

This project includes MIT-licensed upstream work © 2026 Nghia Luong. qiyuey's
changes and distribution are additionally made available under the
[Anti 996 License v1.0](LICENSE-ANTI-996) where legally applicable.
