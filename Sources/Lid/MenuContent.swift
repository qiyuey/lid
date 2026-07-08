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
                SafetySection()
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
            HelperAttentionNotice()
            AutoOffRows()

            if let err = inlineError {
                Label(err, systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    private var inlineError: String? {
        guard let err = state.lastError else { return nil }
        guard !state.usingHelper else { return err }

        let helperAvailabilityMessages = [
            state.text.approveHelperPrompt,
            state.text.approveHelperThenTry,
            state.text.helperNoResponse,
            state.text.installHelperRequiredMessage,
            state.helperUnavailableText
        ]
        return helperAvailabilityMessages.contains(err) ? nil : err
    }
}

private struct HelperAttentionNotice: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if !state.usingHelper {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button(actionTitle) {
                    performAction()
                }
                .buttonStyle(.glassProminent)
                .help(message)
            }
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
    }

    private var text: AppStrings { state.text }

    private var iconName: String {
        state.helperNeedsApproval ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle.fill"
    }

    private var title: String {
        if state.helperNeedsApproval {
            return text.helperApprovalRequiredTitle
        }
        if state.helperInstalled {
            return text.helperUnavailableTitle
        }
        return text.helperRequiredTitle
    }

    private var message: String {
        if state.helperNeedsApproval {
            return text.helperApprovalRequiredBody
        }
        if state.helperInstalled {
            return text.helperUnavailableBody
        }
        return text.helperRequiredBody
    }

    private var actionTitle: String {
        if state.helperNeedsApproval {
            return text.open
        }
        if state.helperInstalled {
            return text.open
        }
        return text.install
    }

    private func performAction() {
        if state.helperNeedsApproval || state.helperInstalled {
            state.openLoginItems()
        } else {
            state.installHelper()
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
            .disabled(!state.usingHelper || state.isChanging)
            .help(state.usingHelper ? text.primaryToggleLabel : state.helperUnavailableText)
        }
    }
}

private struct AutoOffRows: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassRow(title: text.turnOffAfterTitle) {
            Picker("", selection: Binding(
                get: { state.autoOffMinutes },
                set: { state.setAutoOffMinutes($0) }
            )) {
                Text(text.never).tag(0)
                ForEach(AutoOff.presetMinutes, id: \.self) { minutes in
                    Text(text.autoOffOptionLabel(minutes: minutes)).tag(minutes)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }

        if state.isEnabled, !state.autoOffRemaining.isEmpty {
            LiquidGlassRow(title: text.turningOffInTitle) {
                Text(state.autoOffRemaining)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Safety

private struct SafetySection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassSection(title: text.safetyTitle) {
            LiquidGlassRow(title: text.onlyWhileCharging) {
                Toggle(text.onlyWhileCharging, isOn: Binding(
                    get: { state.settings.onlyWhileCharging },
                    set: { value in
                        var settings = state.settings
                        settings.onlyWhileCharging = value
                        state.updateSettings(settings)
                    }
                ))
                .menuSwitchStyle()
            }

            LiquidGlassRow(title: text.pauseWhenHot) {
                Toggle(text.pauseWhenHot, isOn: Binding(
                    get: { state.settings.pauseOnHighThermal },
                    set: { value in
                        var settings = state.settings
                        settings.pauseOnHighThermal = value
                        state.updateSettings(settings)
                    }
                ))
                .menuSwitchStyle()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(text.lowBatteryCutoff)
                        .font(.callout)
                    Spacer(minLength: 16)
                    Text("\(state.settings.lowBatteryThreshold)%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
                .frame(minHeight: 30)

                Slider(value: thresholdBinding, in: 5...50, step: 5) {
                    Text(text.lowBatteryCutoff)
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .accessibilityValue("\(state.settings.lowBatteryThreshold)%")
            }
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { Double(state.settings.lowBatteryThreshold) },
            set: { value in
                var settings = state.settings
                settings.lowBatteryThreshold = Int(value)
                state.updateSettings(settings)
            }
        )
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

            HelperRow()

            LiquidGlassRow(title: text.checkAutomaticallyTitle) {
                Toggle(text.checkAutomaticallyTitle, isOn: $updater.automaticallyChecksForUpdates)
                    .menuSwitchStyle()
            }

            LiquidGlassRow(title: text.versionTitle) {
                Text(state.appVersion)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HelperRow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassRow(title: text.helperTitle, trailingWidth: nil) {
            HStack(spacing: 8) {
                primaryAction
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        let text = state.text
        if state.usingHelper {
            removeButton
        } else if state.helperNeedsApproval {
            removeButton
        } else if state.helperInstalled {
            removeButton
        } else {
            Button(text.install) {
                state.installHelper()
            }
            .buttonStyle(.glassProminent)
            .help(text.onboardingInstallHelper)
        }
    }

    private var removeButton: some View {
        Button(state.text.remove, role: .destructive) {
            state.uninstallHelper()
        }
        .help(state.text.removeHelperTitle)
    }
}

// MARK: - Footer

private struct FooterActions: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: UpdaterController

    var body: some View {
        let text = state.text
        HStack {
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
