import SwiftUI

/// The Settings window. Uses native Liquid Glass effects for every settings
/// group while keeping controls as system Picker, Toggle, Button, and Link.
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var updater: UpdaterController

    private let repoURL = URL(string: "https://github.com/qiyuey/lid")!

    var body: some View {
        let text = state.text
        GlassEffectContainer(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SettingsGlassSection(title: text.sectionGeneral) {
                        SettingsRow(title: text.languageTitle) {
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
                            .buttonStyle(.glass)
                        }

                        SettingsRow(title: text.setupGuideTitle) {
                            Button(text.open) {
                                state.showOnboarding()
                            }
                            .buttonStyle(.glass)
                        }

                        SettingsRow(title: text.launchAtLoginTitle) {
                            Toggle(text.launchAtLoginTitle, isOn: Binding(
                                get: { state.launchAtLogin },
                                set: { state.setLaunchAtLogin($0) }
                            ))
                            .settingsSwitchStyle()
                        }

                        SettingsRow(title: text.continueAfterQuitTitle) {
                            Toggle(text.continueAfterQuitTitle, isOn: Binding(
                                get: { state.settings.continueAfterQuit },
                                set: { value in
                                    var settings = state.settings
                                    settings.continueAfterQuit = value
                                    state.updateSettings(settings)
                                }
                            ))
                            .settingsSwitchStyle()
                        }
                    }

                    SettingsGlassSection(title: text.sectionHelper) {
                        SettingsRow(title: text.helperTitle) {
                            if state.helperInstalled {
                                Button(text.remove, role: .destructive) {
                                    state.uninstallHelper()
                                }
                                .buttonStyle(.glass)
                            } else {
                                Button(state.helperNeedsApproval ? text.open : text.install) {
                                    state.installHelper()
                                }
                                .buttonStyle(.glassProminent)
                            }
                        }

                        if state.helperNeedsApproval {
                            SettingsRow(title: text.pendingHelperTitle) {
                                Button(text.remove, role: .destructive) {
                                    state.uninstallHelper()
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }

                    SettingsGlassSection(title: text.sectionAutoOff) {
                        SettingsRow(title: text.turnOffAfterTitle) {
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
                            .buttonStyle(.glass)
                        }

                        if state.isEnabled, !state.autoOffRemaining.isEmpty {
                            SettingsRow(title: text.turningOffInTitle) {
                                Text(state.autoOffRemaining)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    SettingsGlassSection(title: text.sectionUpdates) {
                        SettingsRow(title: text.checkAutomaticallyTitle) {
                            Toggle(text.checkAutomaticallyTitle, isOn: $updater.automaticallyChecksForUpdates)
                                .settingsSwitchStyle()
                        }

                        SettingsRow(title: text.checkNowTitle) {
                            Button(text.check) { updater.checkForUpdates() }
                                .disabled(!updater.canCheckForUpdates)
                                .buttonStyle(.glass)
                        }
                    }

                    SettingsGlassSection(title: text.sectionAbout) {
                        SettingsRow(title: text.versionTitle) {
                            Text(state.appVersion)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        SettingsRow(title: text.sourceTitle) {
                            Link("GitHub", destination: repoURL)
                                .buttonStyle(.glass)
                        }
                    }
                }
                .padding(18)
            }
        }
        .controlSize(.small)
        .buttonStyle(.glass)
        .frame(width: 420, height: 500)
        .onAppear { NSApp.keyWindow?.title = text.settingsWindowTitle }
        .onChange(of: state.languagePreference) { _, _ in
            NSApp.keyWindow?.title = state.text.settingsWindowTitle
        }
    }
}

private struct SettingsGlassSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)

            Spacer(minLength: 16)

            trailing()
                .fixedSize()
                .frame(width: 116, alignment: .trailing)
        }
        .frame(minHeight: 34)
    }
}

private extension View {
    func settingsSwitchStyle() -> some View {
        labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.accentColor)
    }
}
