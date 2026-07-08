# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid is a lightweight, modern macOS menu-bar app for keeping a MacBook awake
while the lid is closed.

It is built around one idea: do the essential job directly, verify the real
system state, and avoid hidden complexity.

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid menu bar popover" width="360">
</p>

## Philosophy

Lid is intentionally small. It does not try to become a full power-management
suite, and it does not hide the cost of changing a system setting.

- **One clear job**: keep the Mac running with the lid closed when you need
  long-running work to continue.
- **System truth first**: the UI follows the real macOS power state, not an
  optimistic local toggle.
- **Direct control**: when the state changes, Lid asks macOS for administrator
  authorization and applies the system power setting directly.
- **Automatic restore, same path**: while Lid is running, it checks for drift
  and uses the same administrator authorization flow if the last verified state
  needs to be restored.
- **No hidden machinery**: Lid stays a menu-bar app with a compact, native
  interface.

## Works Well For

- AI agent sessions such as Codex, Claude Code, Cursor, OpenClaw, and Hermes.
- Long builds, downloads, sync jobs, and remote sessions.
- Desk setups where the MacBook is closed and stored away.

## Install

### Homebrew

```bash
brew tap qiyuey/tap
brew install --cask lid
```

Upgrade later with:

```bash
brew upgrade --cask lid
```

### Manual Download

Download the latest macOS build from
[GitHub Releases](https://github.com/qiyuey/lid/releases), move `Lid.app` to
`/Applications`, and open it from the menu bar.

Lid requires macOS 26 or later.

If macOS says the app is damaged or cannot be opened, clear the quarantine
attribute after installing:

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## Use

Turn **Lid sleep prevention** on when you want the Mac to keep running with the
lid closed. Turn it off when you want normal lid-close sleep behavior again.

macOS asks for administrator authorization when Lid changes the power setting.
The selected state remains in macOS power settings until you change it again.

The menu also includes:

- **Language**: follow the system language, or choose English or Chinese.
- **Launch at login**: open Lid automatically after signing in.
- **Check automatically**: let Sparkle check for signed updates.

## Verify

For a compact local snapshot:

```bash
./scripts/diagnose.sh
```

To inspect live Lid logs:

```bash
log stream --style compact --info --predicate 'subsystem == "top.qiyuey.lid"'
```

## Remove

Turn **Lid sleep prevention** off, quit Lid, then delete
`/Applications/Lid.app`.

## Development

Developer notes live in [AGENTS.md](AGENTS.md).

## Security

To report a security issue, see [SECURITY.md](SECURITY.md).

## License

See [LICENSE](LICENSE) and [LICENSE-ANTI-996](LICENSE-ANTI-996).
