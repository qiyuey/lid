# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid 是一个为 AI agent 时代打造的轻量 macOS 菜单栏应用。

合盖后，Codex、Claude Code、Cursor、OpenClaw、Hermes、构建、下载和远程会话可以继续运行。

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid 菜单栏弹窗" width="360">
</p>

## 下载

从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载最新的 macOS 签名版本。

Lid 需要 macOS 26 或更高版本。下载后，把 `Lid.app` 移到 `/Applications`，然后从菜单栏打开。

如果 macOS 提示应用已损坏或无法打开，安装后在终端清除隔离属性：

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## 首次使用

使用合盖防睡眠前，Lid 需要安装一个小型特权 Helper。请在设置流程中安装并批准 Helper。

Helper 也负责看门狗恢复：当 **退出后继续生效** 关闭时，如果 Lid 退出或停止发送心跳，Helper 会恢复正常的合盖睡眠。

## 控制项

- **合盖防睡眠**：合盖后仍然让 Mac 保持运行。
- **退出后继续生效**：退出 Lid 后仍然保留合盖防睡眠状态。
- **自动关闭时间**：到达指定时间后自动恢复正常合盖睡眠。
- **仅充电时开启**：Mac 使用电池时暂停合盖防睡眠。
- **温度过高时暂停**：系统热压力较高时暂停合盖防睡眠。
- **低电量阈值**：电量低于指定比例时关闭合盖防睡眠。
- **语言**：跟随系统语言，或固定使用中文 / 英文。
- **登录时启动**：登录 macOS 后自动启动 Lid。
- **自动检查更新**：让 Sparkle 在后台检查已签名的新版本。

底部操作按钮依次用于打开设置向导、手动检查更新、打开 GitHub 项目、退出 Lid。

## 和其他工具对比

| 功能 | Lid | Amphetamine | KeepingYouAwake | `caffeinate` |
| --- | --- | --- | --- | --- |
| 无外接显示器合盖运行 | 支持 | 需配置 | 不支持 | 不支持 |
| 避免反复输入密码 | 支持 | 支持 | 支持 | 不支持 |
| 退出/崩溃后恢复睡眠 | Helper 看门狗 | 不支持 | 不涉及 | 不支持 |
| 电量和温度保护 | 支持 | 部分支持 | 有限 | 不支持 |
| 自动关闭计时器 | 支持 | 支持 | 支持 | 需参数 |
| 开源 | 支持 | 不支持 | 支持 | Apple 系统工具 |
| AI agent 定位 | Codex、Claude Code、Cursor、OpenClaw、Hermes | 通用 | 通用 | 基础命令 |

## 安全

MacBook 在合盖状态下高负载运行可能升温并消耗电量。长时间构建或远程会话时，请尽量接入电源并保持散热通畅。

Lid 的安全保护可以降低风险，但不能替代基本判断。重启总是会重置底层系统睡眠标志。

## 更新和移除

可以使用 Lid 里的更新按钮，或从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载新版本。

如果要停止使用 Lid，先关闭 **合盖防睡眠**，再退出应用。如果安装过后台 Helper，请先在菜单中移除 Helper，再删除 `/Applications/Lid.app`。

## 开发

开发和贡献说明在 [AGENTS.md](AGENTS.md)。

## 安全问题

如需报告安全问题，请阅读 [SECURITY.md](SECURITY.md)。

## 许可证

本项目包含 Nghia Luong 于 2026 年发布的 MIT 授权上游工作。
qiyuey 的修改和分发在法律适用范围内额外采用 [Anti 996 License v1.0](LICENSE-ANTI-996)。
