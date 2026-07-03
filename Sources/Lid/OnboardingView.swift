import SwiftUI

/// First-run setup walkthrough. Explains what Lid does and walks the user
/// through the required system step — installing the background helper —
/// then hands off to the menu bar. Surfaces existing `AppState` flows only; it
/// introduces no new permission logic.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 0
    @State private var didApplyStep4Defaults = false

    private let lastStep = 3
    private let helperStepIndex = 2
    private let windowCornerRadius: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                .glassEffect(in: .rect(cornerRadius: windowCornerRadius))

            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassEffect(in: .rect(cornerRadius: 18))

                    stepContent
                        .id(step)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .animation(.easeInOut(duration: 0.18), value: step)

                    footer
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 18)
            }
        }
        .frame(width: LiquidGlassMetrics.onboardingSize.width, height: LiquidGlassMetrics.onboardingSize.height)
        .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var topBar: some View {
        let text = state.text
        HStack(spacing: 10) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(text.onboardingWindowTitle)
                    .font(.headline)
                Text(text.stepLabel(step: step + 1, total: lastStep + 1))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Spacer()

            progressDots
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0...lastStep, id: \.self) { i in
                Circle()
                    .fill(i == step ? Color.accentColor : Color.secondary.opacity(0.28))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.text.stepLabel(step: step + 1, total: lastStep + 1))
    }

    // MARK: Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcomeStep
        case 1: howItWorksStep
        case 2: helperStep
        default: doneStep
        }
    }

    @ViewBuilder
    private var welcomeStep: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 18) {
            header(symbol: "macbook", title: text.onboardingWelcomeTitle, subtitle: text.onboardingWelcomeSubtitle)
            Text(text.onboardingWelcomeBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                bullet("menubar.rectangle", text.onboardingMenuBullet)
                bullet("moon.zzz.fill", text.onboardingSleepBullet)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var howItWorksStep: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 18) {
            header(symbol: "bolt.fill", title: text.onboardingHowTitle, subtitle: text.onboardingHowSubtitle)
            VStack(alignment: .leading, spacing: 12) {
                bullet("macbook", text.onboardingOverrideBullet)
                bullet("thermometer.medium", text.onboardingSafetyBullet)
                bullet("shield.lefthalf.filled", text.onboardingPersistenceBullet)
            }
            Label(text.onboardingVentilationNote, systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var helperStep: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 18) {
            header(symbol: "key.fill", title: text.onboardingHelperTitle, subtitle: text.onboardingHelperSubtitle)
            Text(text.onboardingHelperBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            helperStatusBox

            Text(text.onboardingHelperRequired)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var helperStatusBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if state.usingHelper {
                Label(state.text.onboardingHelperActive, systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else if state.helperNeedsApproval {
                Label(state.text.onboardingHelperApproval, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    state.installHelper()
                } label: {
                    Label(state.text.onboardingOpenLoginItems, systemImage: "gearshape")
                }
                .buttonStyle(.glass)
            } else {
                Button {
                    state.installHelper()
                } label: {
                    Label(state.text.onboardingInstallHelper, systemImage: "key.fill")
                }
                .buttonStyle(.glassProminent)
            }

            if let err = state.lastError, !state.usingHelper {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    private var doneStep: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 18) {
            header(symbol: "checkmark.circle.fill", title: text.onboardingDoneTitle, subtitle: text.onboardingDoneSubtitle)
            Text(text.onboardingDoneBody)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            onboardingOptionsBox
                .padding(.top, 8)
        }
        .onAppear {
            applyStep4DefaultsIfNeeded()
        }
    }

    @ViewBuilder
    private var onboardingOptionsBox: some View {
        let text = state.text
        VStack(alignment: .leading, spacing: 4) {
            onboardingToggleRow(
                title: text.primaryTitle,
                isOn: Binding(
                    get: { state.isEnabled },
                    set: { state.setEnabled($0, userInitiated: true) }
                ),
                disabled: !state.usingHelper || state.isChanging
            )
            .help(state.usingHelper ? text.primaryToggleLabel : state.helperUnavailableText)

            onboardingToggleRow(
                title: text.onboardingLaunchAtLogin,
                isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) }
                )
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    // MARK: Footer

    @ViewBuilder
    private var footer: some View {
        let text = state.text
        HStack(spacing: 10) {
            Button(text.skip) {
                state.closeOnboarding()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.glass)
            .frame(minWidth: 84)
            .help(text.skip)

            Spacer()

            Button(text.back) {
                withAnimation(.easeInOut(duration: 0.18)) { step -= 1 }
            }
            .disabled(step == 0)
            .opacity(step == 0 ? 0 : 1)
            .buttonStyle(.glass)
            .frame(minWidth: 84)

            Button(step == lastStep ? text.done : text.continue) {
                advanceOrFinish()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.glassProminent)
            .frame(minWidth: 96)
        }
    }

    // MARK: Helpers

    private func header(symbol: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            symbolTile(symbol, size: 58, fontSize: 26)
            Text(title)
                .font(.title.weight(.semibold))
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            symbolTile(symbol, size: 30, fontSize: 14)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        }
    }

    private func onboardingToggleRow(title: String,
                                     isOn: Binding<Bool>,
                                     disabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: isOn)
                .liquidGlassSwitchStyle()
                .disabled(disabled)
        }
        .frame(minHeight: 42)
    }

    private func advanceOrFinish() {
        if step == lastStep {
            state.completeOnboarding()
            return
        }

        if step == helperStepIndex, !state.usingHelper {
            state.installHelper()
            return
        }

        withAnimation(.easeInOut(duration: 0.18)) { step += 1 }
    }

    private func applyStep4DefaultsIfNeeded() {
        guard !didApplyStep4Defaults else { return }
        didApplyStep4Defaults = true

        if state.usingHelper, !state.isEnabled {
            state.setEnabled(true)
        }
    }

    private func symbolTile(_ symbol: String, size: CGFloat, fontSize: CGFloat) -> some View {
        Image(systemName: symbol)
            .font(.system(size: fontSize, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .glassEffect(.regular.tint(.accentColor.opacity(0.18)), in: .rect(cornerRadius: 12))
    }
}
