# Lid

[English](README.md) | [中文](README.zh.md)

[![Downloads](https://img.shields.io/github/downloads/qiyuey/lid/total)](https://github.com/qiyuey/lid/releases)
[![License](https://img.shields.io/badge/license-MIT%20%2B%20Anti--996-blue)](LICENSE)

Lid 是一个轻量的 macOS 菜单栏应用，用来让 Mac 在合盖后仍然持续运行。
它适合编码助手、下载任务、长时间构建、远程会话等需要在 MacBook 合盖后
继续执行的场景。

> Lid 是 qiyuey 面向本地使用和实验维护的个人构建。上游版权和原始 MIT
> 许可证在适用范围内均保留。

<p align="center">
  <img src="docs/menu-popover.png" alt="Lid 菜单栏弹窗，包含合盖防睡眠、安全控制和电池状态" width="420">
</p>

## 下载

从 [GitHub Releases](https://github.com/qiyuey/lid/releases) 下载最新的
macOS 签名版本。

如果 macOS 提示应用已损坏或无法打开，安装后在终端清除隔离属性：

```bash
xattr -rd com.apple.quarantine "/Applications/Lid.app"
```

## 为什么用 Lid

- **合盖防睡眠**：菜单栏一键开启，合盖后任务继续运行。
- **减少密码提示**：可选的特权 Helper 通过 XPC 修改系统开关。
- **看门狗恢复**：默认情况下，如果 Lid 退出或崩溃，Helper 会恢复正常睡眠。
- **显式持久化**：只有开启 **退出后继续生效** 时，退出应用后才保持合盖防睡眠。
- **安全保护**：温度过高时暂停、可限制仅充电时开启、可设置低电量阈值。
- **自动关闭计时器**：15 分钟到 4 小时后自动恢复正常合盖睡眠。
- **自动更新**：Sparkle 在后台检查已签名的新版本。
- **语言设置**：默认跟随系统，也可以手动选择中文或英文。

## 工作原理

macOS 默认会在 MacBook 合盖时进入睡眠。在 Apple Silicon 上，可靠覆盖这一
行为的方式是修改 `IOPMrootDomain` 里的 `SleepDisabled` 标志，也就是：

```bash
sudo pmset -a disablesleep 1
```

`caffeinate` 无法阻止合盖睡眠。Lid 通过 `SMAppService` 注册一个 root
Helper，由 Helper 修改 `SleepDisabled`，这样每次开关时都不需要输入管理员
密码。合盖防睡眠开启时，应用会向 Helper 发送心跳；如果心跳停止，并且没有
开启 **退出后继续生效**，Helper 会自动恢复正常睡眠。

## 构建

Lid 是 SwiftUI 菜单栏应用，项目由 XcodeGen 生成。`project.yml` 是项目配置
的唯一来源。

```bash
xcodegen generate
xcodebuild test -scheme Lid-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

主要目录：

- `Sources/Lid`：SwiftUI 应用、设置、引导、更新、Helper 生命周期。
- `Sources/Helper`：通过 `SMAppService` 注册的特权 root Helper。
- `Sources/Shared`：应用、Helper 和测试共享的纯逻辑。
- `Tests/LidTests`：解析器、安全策略、设置、Helper 身份等 XCTest 覆盖。
- `Resources/Assets.xcassets`：应用图标和菜单栏模板图片。
- `scripts`：发布自动化、Sparkle 工具和辅助脚本。

## 发布

版本号使用 `YYYY.M.N`，例如 `2026.7.1`。`MARKETING_VERSION` 和
`CURRENT_PROJECT_VERSION` 需要保持一致。

签名和公证发布需要 Developer ID 证书、notarytool 凭据，以及 Sparkle EdDSA
签名密钥：

```bash
./scripts/release.sh
```

脚本会构建 DMG、完成公证和 stapling、发布 GitHub Release，并将 Sparkle
appcast 写入 `docs/appcast.xml`。

## 安全

MacBook 在合盖状态下高负载运行可能升温并消耗电量。请尽量接入电源并保持
散热通畅。Lid 的安全保护可以降低风险，重启也会重置底层的
`SleepDisabled` 标志。

如需报告安全问题，请阅读 [SECURITY.md](SECURITY.md)。

## 许可证

本项目包含 Nghia Luong 于 2026 年发布的 MIT 授权上游工作。qiyuey 的修改
和分发在法律适用范围内额外采用 [Anti 996 License v1.0](LICENSE-ANTI-996)。
