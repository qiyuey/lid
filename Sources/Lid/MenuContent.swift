import AppKit
import SwiftUI

private let menuInset: CGFloat = 10
private let repoURL = URL(string: "https://github.com/qiyuey/lid")!

/// The menu bar popover. It owns every user-facing setting so Lid does not need
/// a separate settings window.
struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                CoreSection()
                AppSection()
                FooterActions()
            }
            .padding(menuInset)
        }
        .controlSize(.small)
        .buttonStyle(.glass)
        .frame(width: LiquidGlassMetrics.menuWidth)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            state.menuDidAppear()
        }
    }
}

private extension View {
    func menuSwitchStyle() -> some View {
        liquidGlassSwitchStyle()
    }
}

// MARK: - Core control

private struct CoreSection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassSection(title: text.sectionControls) {
            PrimaryToggleRow()

            if let err = state.lastError {
                Label(err, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }
}

/// The strongest row in the popover: the main lid sleep prevention action.
private struct PrimaryToggleRow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassRow(title: text.primaryTitle, titleFont: .callout) {
            Toggle(text.primaryToggleLabel, isOn: Binding(
                get: { state.isEnabled },
                set: { value in state.setEnabled(value, userInitiated: true) }
            ))
            .menuSwitchStyle()
            .disabled(state.isChanging)
            .help(text.primaryToggleLabel)
        }
    }
}

// MARK: - App

private struct AppSection: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: UpdaterController

    var body: some View {
        let text = state.text
        LiquidGlassSection(title: text.sectionApp) {
            LiquidGlassRow(title: text.languageTitle) {
                Picker("", selection: Binding(
                    get: { state.languagePreference },
                    set: { state.setLanguagePreference($0) }
                )) {
                    ForEach(AppLanguagePreference.allCases) { preference in
                        Text(preference.displayName(using: text)).tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            LiquidGlassRow(title: text.launchAtLoginTitle) {
                Toggle(text.launchAtLoginTitle, isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                ))
                .menuSwitchStyle()
            }

            LiquidGlassRow(title: text.checkAutomaticallyTitle) {
                Toggle(text.checkAutomaticallyTitle, isOn: $updater.automaticallyChecksForUpdates)
                    .menuSwitchStyle()
            }
        }
    }
}

// MARK: - Footer

private struct FooterActions: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: UpdaterController

    var body: some View {
        let text = state.text
        HStack {
            Text("v\(state.appVersion)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Spacer()

            Button {
                state.showOnboarding()
            } label: {
                FooterSymbol(systemName: "questionmark.circle.fill")
            }
            .help(text.setupGuideTitle)
            .accessibilityLabel(text.setupGuideTitle)

            Button {
                updater.checkForUpdates()
            } label: {
                FooterSymbol(systemName: "arrow.clockwise.circle.fill")
            }
            .disabled(!updater.canCheckForUpdates)
            .help(text.checkNowTitle)
            .accessibilityLabel(text.checkNowTitle)

            Button {
                NSWorkspace.shared.open(repoURL)
            } label: {
                FooterAsset(name: "GitHubMark")
            }
            .help("GitHub")
            .accessibilityLabel("GitHub")

            Button {
                state.quit()
            } label: {
                FooterSymbol(systemName: "power.circle.fill")
            }
            .keyboardShortcut("q")
            .help(text.quitLid)
            .accessibilityLabel(text.quitLid)
        }
        .buttonStyle(.glass)
        .foregroundStyle(.secondary)
        .frame(minHeight: 30)
        .padding(.horizontal, 12)
    }
}

private struct FooterSymbol: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .frame(width: 17, height: 17)
            .frame(width: 24, height: 24)
    }
}

private struct FooterAsset: View {
    let name: String

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 17, height: 17)
            .frame(width: 24, height: 24)
    }
}
