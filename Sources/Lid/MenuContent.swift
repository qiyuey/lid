import SwiftUI

/// The menu bar popover — "Minimal Quick Toggle".
///
/// Keeps only the essentials: the primary keep-awake switch, the current
/// battery context, and the core safety controls. Everything secondary (helper
/// setup, launch at login, auto-off timer, GitHub) lives in Settings.
struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                LiquidGlassPanel(cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        PrimaryToggleRow()
                        ContinueAfterQuitRow()

                        if let err = state.lastError {
                            Label(err, systemImage: "info.circle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                        }
                    }
                }

                if !state.usingHelper {
                    HelperNotice()
                }

                LiquidGlassPanel(cornerRadius: 20) {
                    SafetySection()
                }

                LiquidGlassPanel(cornerRadius: 18, verticalPadding: 8) {
                    FooterActions()
                }
            }
            .padding(10)
        }
        .frame(width: LiquidGlassMetrics.menuWidth)
    }
}

private extension View {
    func menuSwitchStyle() -> some View {
        liquidGlassSwitchStyle()
    }
}

// MARK: - Primary control

/// The strongest row in the popover: the main lid sleep prevention action.
private struct PrimaryToggleRow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassRow(title: text.primaryTitle,
                       subtitle: state.isEnabled ? text.primaryOnSubtitle : text.primaryOffSubtitle,
                       titleFont: .callout,
                       minHeight: 46) {
            Toggle(text.primaryToggleLabel, isOn: Binding(
                get: { state.isEnabled },
                set: { value in state.setEnabled(value, userInitiated: true) }
            ))
            .menuSwitchStyle()
            .disabled(!state.usingHelper)
            .help(state.usingHelper ? text.primaryToggleLabel : text.installHelperRequiredMessage)
        }
    }
}

private struct ContinueAfterQuitRow: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        LiquidGlassRow(title: text.continueAfterQuitTitle,
                       subtitle: state.settings.continueAfterQuit ? text.continueAfterQuitOnSubtitle : text.continueAfterQuitOffSubtitle,
                       minHeight: 46) {
            Toggle(text.continueAfterQuitTitle, isOn: Binding(
                get: { state.settings.continueAfterQuit },
                set: { value in
                    var settings = state.settings
                    settings.continueAfterQuit = value
                    state.updateSettings(settings)
                }
            ))
            .menuSwitchStyle()
            .help(text.continueAfterQuitHelp)
        }
    }
}

// MARK: - Helper

private struct HelperNotice: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        LiquidGlassPanel(cornerRadius: 16, verticalPadding: 8, horizontalPadding: 10) {
            HStack(spacing: 12) {
                Label(title, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.orange)
                    .lineLimit(1)

                Spacer(minLength: 12)

                Button(buttonTitle) {
                    state.installHelper()
                }
                .controlSize(.small)
                .buttonStyle(.glassProminent)
                .help(buttonHelp)
            }
        }
    }

    private var title: String {
        state.helperNeedsApproval ? state.text.helperNeedsApprovalNotice : state.text.helperNotice
    }

    private var buttonTitle: String {
        state.helperNeedsApproval ? state.text.open : state.text.install
    }

    private var buttonHelp: String {
        state.helperNeedsApproval ? state.text.onboardingOpenLoginItems : state.text.onboardingInstallHelper
    }
}

// MARK: - Safety

private struct SafetySection: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(text.safetyTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                BatteryStatus(percent: state.batteryPercent, onAC: state.batteryOnAC)
            }
            .padding(.bottom, 6)

            LiquidGlassRow(title: text.onlyWhileCharging, trailingWidth: nil) {
                Toggle(text.onlyWhileCharging, isOn: Binding(
                    get: { state.settings.onlyWhileCharging },
                    set: { v in var s = state.settings; s.onlyWhileCharging = v; state.updateSettings(s) }
                ))
                .menuSwitchStyle()
            }

            LiquidGlassRow(title: text.pauseWhenHot, trailingWidth: nil) {
                Toggle(text.pauseWhenHot, isOn: Binding(
                    get: { state.settings.pauseOnHighThermal },
                    set: { v in var s = state.settings; s.pauseOnHighThermal = v; state.updateSettings(s) }
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

private struct BatteryStatus: View {
    @EnvironmentObject var state: AppState

    let percent: Int
    let onAC: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 22, alignment: .trailing)
            Text("\(percent)%")
                .monospacedDigit()
                .frame(width: 36, alignment: .trailing)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.text.batteryAccessibility(percent: percent, onAC: onAC))
    }

    private var symbol: String {
        switch percent {
        case 88...:   return "battery.100"
        case 63..<88: return "battery.75"
        case 38..<63: return "battery.50"
        case 13..<38: return "battery.25"
        default:      return "battery.0"
        }
    }
}

// MARK: - Footer

private struct FooterActions: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            SettingsButton()
            Spacer()
            Button {
                state.quit()
            } label: {
                Image(systemName: "power")
            }
            .keyboardShortcut("q")
            .help(state.text.quitLid)
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .font(.title3)
        .frame(minHeight: 30)
    }
}

/// Opens Lid's Settings window.
private struct SettingsButton: View {
    @EnvironmentObject var settingsController: SettingsController
    @EnvironmentObject var state: AppState

    var body: some View {
        Button {
            settingsController.show()
        } label: {
            Image(systemName: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)
        .help(state.text.settings)
        .buttonStyle(.glass)
        .controlSize(.small)
    }
}
