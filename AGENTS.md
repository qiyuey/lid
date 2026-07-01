# Repository Guidelines

## Project Structure & Module Organization

Lid is a macOS SwiftUI menu-bar app generated with XcodeGen. `project.yml` is the source of truth; do not hand-edit the generated `Lid.xcodeproj`.

- `Sources/Lid/`: app UI, app state, updater, onboarding, settings, and helper lifecycle code.
- `Sources/Helper/`: privileged root helper launched through `SMAppService`.
- `Sources/Shared/`: pure shared logic used by the app, helper, and tests.
- `Tests/LidTests/`: XCTest coverage for shared logic and safety behavior.
- `Resources/Assets.xcassets/`: app icon and menu-bar template images.
- `scripts/`: release automation, Sparkle tooling, icon helpers, and the lid-close spike script.
- `docs/`: public assets such as screenshots and the Sparkle appcast.

## Build, Test, and Development Commands

Install Xcode command-line tools plus `xcodegen`; `xcbeautify` is optional.

```bash
xcodegen generate
```

Regenerates `Lid.xcodeproj` from `project.yml`.

```bash
xcodebuild test -scheme Lid-CI -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO | xcbeautify
```

Runs the local CI test scheme. The unformatted command is fine if `xcbeautify` is unavailable.

```bash
xcodebuild build -scheme Lid -destination 'generic/platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO
```

Builds the debug app without requiring signing. Use `./scripts/release.sh` only on a Mac configured for Developer ID signing, notarization, and Sparkle signing.

## Coding Style & Naming Conventions

Use Swift 5 conventions with 4-space indentation. Keep SwiftUI app code in `Sources/Lid`, helper-only code in `Sources/Helper`, and deterministic logic in `Sources/Shared`. Prefer small, explicit types such as `SafetyEvaluator`, `BatteryMonitor`, and `HelperLifecycleController`. Use `// MARK:` only where it improves navigation.

## Testing Guidelines

Tests use XCTest. Add or update tests in `Tests/LidTests` when changing parsers, safety policy, watchdog behavior, settings persistence, helper identity, or auto-off logic. Name tests with the `test...` prefix and make expected behavior clear, for example `testSafetyDisablesOnLowBattery`. Run `Lid-CI` before opening a PR.

## Release & Versioning

Versions use calendar form `YYYY.M.N`, for example `2026.7.1`. Increment `N` for every release in the same month, including multiple releases on the same day. Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` equal so Sparkle does not show a separate build number.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages and occasional Conventional Commit prefixes, such as `docs: add total downloads badge`. Keep commits focused. PRs should describe user-visible behavior, list local verification commands, link relevant issues, and include screenshots or recordings for menu/UI changes.

## Security & Configuration Tips

This app controls lid-close sleep through privileged helper behavior. Avoid silent failure paths, preserve watchdog restore behavior, and keep Debug bundle IDs isolated from Release IDs as defined in `project.yml`.
