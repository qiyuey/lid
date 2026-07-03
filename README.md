# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid is a tiny macOS menu-bar app built for the AI-agent era. It keeps your Mac
running with the lid closed so Codex, Claude Code, Cursor, OpenClaw, Hermes,
builds, downloads, and remote sessions can keep working while your MacBook is
tucked away.

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

Lid requires a small privileged helper before it can change lid sleep
prevention. Install and approve the helper during setup.

The helper owns and persists the selected lid sleep-prevention state. If Lid
quits, the helper keeps the last selected state until you turn lid sleep
prevention off, use the auto-off timer while Lid is running, or remove the
helper from the menu.

## Diagnostics

For helper, XPC, or sleep-state issues, collect a compact local snapshot:

```bash
./scripts/diagnose.sh
```

To inspect live Lid logs:

```bash
log stream --style compact --info --predicate 'subsystem == "top.qiyuey.lid"'
```

## Controls

- **Lid sleep prevention** keeps the Mac awake when the lid is closed.
- **Turn off after** automatically returns to normal lid-close sleep after a
  chosen time while Lid is running.
- **Only while charging** pauses lid sleep prevention when the Mac is on
  battery power.
- **Pause when running hot** pauses lid sleep prevention during high thermal
  pressure.
- **Low-battery cutoff** turns lid sleep prevention off when battery level drops
  below the selected percentage.
- **Language** follows the system language or locks the app to English or
  Chinese.
- **Launch at login** starts the Lid app automatically after signing in. The
  background helper is managed separately by macOS once installed and approved.
- **Check automatically** lets Sparkle check for signed updates in the
  background.

The bottom action row opens the setup guide, checks for updates, opens the
GitHub project, and quits Lid.

## Compared With Other Tools

| Feature | Lid | Amphetamine | KeepingYouAwake | `caffeinate` |
| --- | --- | --- | --- | --- |
| Lid-closed, no display | Yes | Needs setup | No | No |
| No repeated password prompts | Yes | Yes | Yes | No |
| Quit behavior | Helper keeps selected state | App-dependent | Not applicable | No |
| Battery and thermal guards | Yes | Partial | Limited | No |
| Auto-off timer | Yes | Yes | Yes | With flags |
| Open source | Yes | No | Yes | Apple system tool |
| AI focus | Codex/Claude/Cursor/OpenClaw/Hermes | General | General | CLI |

## Safety

Running a MacBook closed under heavy load can increase heat and drain battery.
Keep the machine plugged in and ventilated, especially during long builds or
remote sessions.

Lid's safety controls reduce risk, but they do not replace common sense. The
auto-off timer and safety guards run in the app; if Lid is not running, the
helper preserves the last selected state.

## Updates and Removal

Use the update button in Lid or download a newer build from
[GitHub Releases](https://github.com/qiyuey/lid/releases).

To stop using Lid, turn **Lid sleep prevention** off first, then quit the app.
If you installed the background helper, remove it from the menu before deleting
`/Applications/Lid.app`.

## Development

Developer and contributor notes live in [AGENTS.md](AGENTS.md).

## Security

To report a security issue, see [SECURITY.md](SECURITY.md).

## License

This project includes MIT-licensed upstream work © 2026 Nghia Luong. qiyuey's
changes and distribution are additionally made available under the
[Anti 996 License v1.0](LICENSE-ANTI-996) where legally applicable.
