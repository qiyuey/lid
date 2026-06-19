import SwiftUI

struct MenuContent: View {
    @EnvironmentObject var state: AppState

    private let repoURL = URL(string: "https://github.com/nghialuong/Lidless")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lidless").font(.headline)
                Spacer()
                Text("v\(state.appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(state.isEnabled
                 ? "Keeping the Mac awake with the lid closed."
                 : "Mac sleeps normally when the lid closes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Keep awake with lid closed", isOn: Binding(
                get: { state.isEnabled },
                set: { _ in state.toggle() }
            ))
            .toggleStyle(.switch)

            Divider()

            // Helper / first-run setup
            HStack(spacing: 6) {
                Image(systemName: state.usingHelper ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundStyle(state.usingHelper ? .green : .orange)
                Text(state.usingHelper ? "Background helper active" : "Using admin prompt (no helper)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !state.helperInstalled {
                Text("Install the background helper once so toggling never asks for your password and the watchdog can protect against a stuck-awake Mac.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(state.helperNeedsApproval ? "Open Login Items to approve" : "Install background helper") {
                    state.installHelper()
                }
                .font(.caption)
            }

            HStack(spacing: 6) {
                Image(systemName: "battery.100").foregroundStyle(.secondary)
                Text(state.batteryDescription).font(.caption).foregroundStyle(.secondary)
                Spacer()
            }

            Divider()

            Text("Safety").font(.caption.bold()).foregroundStyle(.secondary)

            Toggle("Only while charging", isOn: Binding(
                get: { state.settings.onlyWhileCharging },
                set: { v in var s = state.settings; s.onlyWhileCharging = v; state.updateSettings(s) }
            ))
            .toggleStyle(.checkbox).font(.caption)

            Toggle("Pause when running hot", isOn: Binding(
                get: { state.settings.pauseOnHighThermal },
                set: { v in var s = state.settings; s.pauseOnHighThermal = v; state.updateSettings(s) }
            ))
            .toggleStyle(.checkbox).font(.caption)

            Stepper(value: Binding(
                get: { state.settings.lowBatteryThreshold },
                set: { v in var s = state.settings; s.lowBatteryThreshold = v; state.updateSettings(s) }
            ), in: 5...50, step: 5) {
                Text("Low-battery cutoff: \(state.settings.lowBatteryThreshold)%").font(.caption)
            }

            Divider()

            Text("Auto-off timer").font(.caption.bold()).foregroundStyle(.secondary)

            Picker(selection: Binding(
                get: { state.autoOffMinutes },
                set: { state.setAutoOffMinutes($0) }
            )) {
                Text("Never").tag(0)
                ForEach(AutoOff.presetMinutes, id: \.self) { m in
                    Text(AutoOff.optionLabel(minutes: m)).tag(m)
                }
            } label: {
                Text("Turn off after").font(.caption)
            }
            .pickerStyle(.menu).font(.caption)

            if state.isEnabled, !state.autoOffRemaining.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "timer").foregroundStyle(.secondary)
                    Text("Turning off in \(state.autoOffRemaining)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            if let err = state.lastError {
                Text(err).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            .toggleStyle(.checkbox).font(.caption)

            HStack {
                Link("GitHub", destination: repoURL).font(.caption)
                Spacer()
                Button("Quit Lidless") { NSApplication.shared.terminate(nil) }
                    .font(.caption)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
