# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid 是一个为 AI agent 时代打造的轻量、现代化 macOS 菜单栏应用。

合盖后，Codex、Claude Code、Cursor、OpenClaw、Hermes、构建、下载和远程会话可以继续运行。

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid 菜单栏弹窗" width="360">
</p>

## 下载

从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载最新的 macOS 自签名版本。

### Homebrew

```bash
brew tap qiyuey/tap
brew install --cask lid
```

之后更新：

```bash
brew upgrade --cask lid
```

### 手动下载

Lid 需要 macOS 26 或更高版本。下载后，把 `Lid.app` 移到 `/Applications`，然后从菜单栏打开。

如果 macOS 提示应用已损坏或无法打开，安装后在终端清除隔离属性：

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## 首次使用

Lid 会直接修改 macOS 电源设置。开启或关闭合盖防睡眠时，macOS 会要求管理员授权。

选定状态会保留在 macOS 电源设置中，直到你手动关闭。菜单栏 app 每次打开时都会读取当前状态。

## 为什么选择 Lid

- **轻量设计**：只有一个菜单栏 app，没有额外的系统后台组件或常驻服务。
- **现代 macOS 体验**：原生 SwiftUI 控件、Liquid Glass 风格、中英文界面，以及已签名的 Sparkle 更新。
- **直接且可验证**：Lid 修改系统 `SleepDisabled` 设置后，会读取真实 `pmset` 状态再更新界面。
- **面向长时间任务**：合盖收纳 MacBook 时，agent 会话、构建、下载和远程访问仍可继续运行。

## 诊断

遇到睡眠状态问题时，可以收集一份本机诊断快照：

```bash
./scripts/diagnose.sh
```

实时查看 Lid 日志：

```bash
log stream --style compact --info --predicate 'subsystem == "top.qiyuey.lid"'
```

## 控制项

- **合盖防睡眠**：合盖后仍然让 Mac 保持运行。
- **语言**：跟随系统语言，或固定使用中文 / 英文。
- **登录时启动**：登录 macOS 后自动启动 Lid app。
- **自动检查更新**：让 Sparkle 在后台检查已签名的新版本。

底部操作按钮依次用于打开设置向导、手动检查更新、打开 GitHub 项目、退出 Lid。

## 更新和移除

可以使用 Lid 里的更新按钮，或从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载新版本。

如果要停止使用 Lid，先关闭 **合盖防睡眠**，再退出应用并删除 `/Applications/Lid.app`。

## 开发

开发和贡献说明在 [AGENTS.md](AGENTS.md)。

## 安全问题

如需报告安全问题，请阅读 [SECURITY.md](SECURITY.md)。

## 许可证

本项目包含 Nghia Luong 于 2026 年发布的 MIT 授权上游工作。
qiyuey 的修改和分发在法律适用范围内额外采用 [Anti 996 License v1.0](LICENSE-ANTI-996)。
