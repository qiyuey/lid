# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid 是一个轻量、现代化的 macOS 菜单栏应用，用来让 MacBook 在合盖后继续运行。

它的理念很简单：直接完成核心任务，验证真实系统状态，避免隐藏复杂度。

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid 菜单栏弹窗" width="360">
</p>

## 理念

Lid 刻意保持小而清晰。它不试图变成完整的电源管理套件，也不会把修改系统设置的代价藏起来。

- **只做一件事**：在你需要长时间任务继续运行时，让 Mac 合盖后保持工作。
- **以系统真实状态为准**：界面跟随 macOS 当前电源状态，而不是相信一个本地开关。
- **直接控制**：状态变化时，Lid 请求 macOS 管理员授权，然后直接应用系统电源设置。
- **同一路径自动恢复**：Lid 运行时会检查状态是否偏离；如果需要恢复最后一次确认状态，会走同一套管理员授权流程。
- **不隐藏复杂组件**：Lid 保持为一个紧凑、原生的菜单栏应用。

## 适合场景

- Codex、Claude Code、Cursor、OpenClaw、Hermes 等 AI agent 会话。
- 长时间构建、下载、同步任务和远程连接。
- MacBook 合盖收纳的桌面环境。

## 安装

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

从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载最新 macOS 版本，把 `Lid.app`
移到 `/Applications`，然后从菜单栏打开。

Lid 需要 macOS 26 或更高版本。

如果 macOS 提示应用已损坏或无法打开，安装后在终端清除隔离属性：

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## 使用

需要合盖后继续运行时，打开 **合盖防睡眠**。需要恢复正常合盖睡眠时，再把它关闭。

Lid 修改电源设置时，macOS 会要求管理员授权。选定状态会保留在 macOS 电源设置中，直到你再次修改。

菜单中还包括：

- **语言**：跟随系统语言，或固定使用中文 / 英文。
- **登录时启动**：登录 macOS 后自动打开 Lid。
- **自动检查更新**：让 Sparkle 检查已签名的新版本。

## 验证

收集本机诊断快照：

```bash
./scripts/diagnose.sh
```

实时查看 Lid 日志：

```bash
log stream --style compact --info --predicate 'subsystem == "top.qiyuey.lid"'
```

## 移除

先关闭 **合盖防睡眠**，退出 Lid，然后删除 `/Applications/Lid.app`。

## 开发

开发说明见 [AGENTS.md](AGENTS.md)。

## 安全问题

如需报告安全问题，请阅读 [SECURITY.md](SECURITY.md)。

## 许可证

见 [LICENSE](LICENSE) 和 [LICENSE-ANTI-996](LICENSE-ANTI-996)。
