# Repository Guidelines

## Project Structure & Module Organization

Lid is a macOS SwiftUI menu-bar app generated with XcodeGen. `project.yml` is
the source of truth; do not hand-edit the generated `Lid.xcodeproj`.

- `Sources/Lid/`: app UI, menu settings, app state, updater, onboarding, and
  direct macOS power-setting control.
- `Sources/Shared/`: pure shared logic used by the app and tests.
- `Tests/LidTests/`: XCTest coverage for shared logic and app behavior.
- `Resources/Assets.xcassets/`: app icon and menu-bar template images.
- `scripts/`: release automation, Sparkle tooling, icon generation tools, and the
  lid-close spike script.
- `docs/`: public assets such as screenshots and the Sparkle appcast.

There is no separate Settings page or Settings window. `MenuContent` is the
single user-facing control surface for all settings and status actions; do not
add a SwiftUI `Settings` scene or AppKit settings window.

## Build, Test, and Development Commands

Install Xcode command-line tools plus `xcodegen`; `xcbeautify` is optional.

```bash
xcodegen generate
```

Regenerates `Lid.xcodeproj` from `project.yml`.

```bash
xcodebuild test \
  -scheme Lid-CI \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  | xcbeautify
```

Runs the local CI test scheme. The unformatted command is fine if `xcbeautify`
is unavailable.

```bash
xcodebuild build \
  -scheme Lid \
  -destination 'generic/platform=macOS' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

Builds the debug app without requiring signing. Use `./scripts/release.sh` only
as the compatibility entrypoint for the tag-driven self-signed release workflow.
Published artifacts must stay on the self-signed path.

```bash
./scripts/install-self-signed-release.sh
```

Builds the self-signed Release DMG and installs that app into `/Applications`
for same-machine testing. Do not install the raw `xcodebuild -configuration
Release` product directly: Xcode automatic signing may produce an Apple
Development-signed app, while local installs and published Homebrew/GitHub
artifacts must stay on the self-signed path. This does not notarize, staple,
update Sparkle appcasts, or publish GitHub releases.

## Coding Style & Naming Conventions

Use Swift 6 conventions with 4-space indentation. Keep SwiftUI app code in
`Sources/Lid` and deterministic logic in `Sources/Shared`. Prefer small,
explicit types such as `PowerController`. Use `// MARK:` only where it improves
navigation.

Menu UI should stay compact and native:

- Keep settings in the menu-bar popover, grouped through titled `MenuSection`
  blocks and rows through `SettingRow`; prefer a small number of consolidated
  groups such as core controls and app maintenance.
- Use native SwiftUI Liquid Glass surfaces (`.glassEffect`,
  `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`) and system controls
  (`Toggle`, `Picker`, `Slider`, `Button`, `Link`); do not fake glass with
  custom gradients or drawn backgrounds.
- Keep trailing controls aligned to the shared right column in `SettingRow`.
- Do not add explanatory subtitle text inside menu rows unless the user
  explicitly asks for it.
- Keep Setup Guide, manual update check, GitHub/source, and quit in the bottom
  action row, without an extra enclosing menu section/frame. Use native glass
  icon buttons for clear system actions, use the GitHub mark for the source
  action, and attach `.help(...)` hover tooltips to every icon-only action.
- Keep the setup guide readable on a native Liquid Glass/material background in
  a borderless window with no system traffic-light controls. Center it manually
  in the visible frame of the presentation screen; do not rely on
  `NSWindow.center()` for this LSUIElement borderless window. Put `Skip`/`跳过`
  in the bottom-left corner and Back immediately before Continue/Done on the
  bottom-right, without wrapping those buttons in an extra footer glass
  container. Keep setup bullet icons vertically aligned with their text.

## Testing Guidelines

Tests use XCTest. Add or update tests in `Tests/LidTests` when changing
parsers, direct power-setting commands, settings persistence, or menu behavior.
Name tests with the `test...` prefix and make expected behavior clear. Run
`Lid-CI` before opening a PR.

## Release & Versioning

Versions use calendar form `YYYY.M.N`, for example `2026.7.1`. Increment `N`
for every release in the same month, including multiple releases on the same
day. Keep `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` equal so Sparkle
does not show a separate build number.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages and occasional Conventional
Commit prefixes, such as `docs: add total downloads badge`. Keep commits
focused. PRs should describe user-visible behavior, list local verification
commands, link relevant issues, and include screenshots or recordings for
menu/UI changes.

## Security & Configuration Tips

This app controls lid-close sleep by asking macOS for administrator
authorization and setting `pmset -a disablesleep` directly. Avoid silent failure
paths, confirm the observed `SleepDisabled` state after changes, and keep Debug
bundle IDs isolated from Release IDs as defined in `project.yml`.
