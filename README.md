# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid is a lightweight, modern macOS menu-bar app for the AI-agent era. It keeps
your Mac running with the lid closed so Codex, Claude Code, Cursor, OpenClaw,
Hermes, builds, downloads, and remote sessions can keep working while your
MacBook is tucked away.

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid menu bar popover" width="360">
</p>

## Download

Get the latest self-signed macOS build from
[GitHub Releases](https://github.com/qiyuey/lid/releases).

### Homebrew

```bash
brew tap qiyuey/tap
brew install --cask lid
```

To upgrade later:

```bash
brew upgrade --cask lid
```

### Manual Download

Lid requires macOS 26 or later. After downloading, move `Lid.app` to
`/Applications` and open it from the menu bar.

If macOS says the app is damaged or cannot be opened, clear the quarantine
attribute after installing:

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## First Run

Lid changes the macOS power setting directly. When you turn lid sleep prevention
on or off, macOS asks for administrator authorization.

The selected state stays in macOS power settings until you turn it off. The
menu-bar app reads the current setting whenever it opens.

## Why Lid

- **Lightweight by design**: one menu-bar app, with no extra system background
  component or always-running service.
- **Modern macOS experience**: native SwiftUI controls, Liquid Glass styling,
  bilingual UI, and signed Sparkle updates.
- **Direct and predictable**: Lid changes the system `SleepDisabled` setting,
  then verifies the real `pmset` state before updating the UI.
- **Built for long-running work**: agent sessions, builds, downloads, and
  remote access can continue while the MacBook is closed and stored away.

## Diagnostics

For sleep-state issues, collect a compact local snapshot:

```bash
./scripts/diagnose.sh
```

To inspect live Lid logs:

```bash
log stream --style compact --info --predicate 'subsystem == "top.qiyuey.lid"'
```

## Controls

- **Lid sleep prevention** keeps the Mac awake when the lid is closed.
- **Language** follows the system language or locks the app to English or
  Chinese.
- **Launch at login** starts the Lid app automatically after signing in.
- **Check automatically** lets Sparkle check for signed updates in the
  background.

The bottom action row opens the setup guide, checks for updates, opens the
GitHub project, and quits Lid.

## Updates and Removal

Use the update button in Lid or download a newer build from
[GitHub Releases](https://github.com/qiyuey/lid/releases).

To stop using Lid, turn **Lid sleep prevention** off first, then quit the app
and delete `/Applications/Lid.app`.

## Development

Developer and contributor notes live in [AGENTS.md](AGENTS.md).

## Security

To report a security issue, see [SECURITY.md](SECURITY.md).

## License

This project includes MIT-licensed upstream work © 2026 Nghia Luong. qiyuey's
changes and distribution are additionally made available under the
[Anti 996 License v1.0](LICENSE-ANTI-996) where legally applicable.
