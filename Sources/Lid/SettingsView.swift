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
                    LiquidGlassSection(title: text.sectionGeneral) {
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
                            .buttonStyle(.glass)
                        }

                        LiquidGlassRow(title: text.setupGuideTitle) {
                            Button(text.open) {
                                state.showOnboarding()
                            }
                            .buttonStyle(.glass)
                        }

                        LiquidGlassRow(title: text.launchAtLoginTitle) {
                            Toggle(text.launchAtLoginTitle, isOn: Binding(
                                get: { state.launchAtLogin },
                                set: { state.setLaunchAtLogin($0) }
                            ))
                            .liquidGlassSwitchStyle()
                        }

                        LiquidGlassRow(title: text.continueAfterQuitTitle) {
                            Toggle(text.continueAfterQuitTitle, isOn: Binding(
                                get: { state.settings.continueAfterQuit },
                                set: { value in
                                    var settings = state.settings
                                    settings.continueAfterQuit = value
                                    state.updateSettings(settings)
                                }
                            ))
                            .liquidGlassSwitchStyle()
                        }
                    }

                    LiquidGlassSection(title: text.sectionHelper) {
                        LiquidGlassRow(title: text.helperTitle) {
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
                            LiquidGlassRow(title: text.pendingHelperTitle) {
                                Button(text.remove, role: .destructive) {
                                    state.uninstallHelper()
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }

                    LiquidGlassSection(title: text.sectionAutoOff) {
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
                            .buttonStyle(.glass)
                        }

                        if state.isEnabled, !state.autoOffRemaining.isEmpty {
                            LiquidGlassRow(title: text.turningOffInTitle) {
                                Text(state.autoOffRemaining)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    LiquidGlassSection(title: text.sectionUpdates) {
                        LiquidGlassRow(title: text.checkAutomaticallyTitle) {
                            Toggle(text.checkAutomaticallyTitle, isOn: $updater.automaticallyChecksForUpdates)
                                .liquidGlassSwitchStyle()
                        }

                        LiquidGlassRow(title: text.checkNowTitle) {
                            Button(text.check) { updater.checkForUpdates() }
                                .disabled(!updater.canCheckForUpdates)
                                .buttonStyle(.glass)
                        }
                    }

                    LiquidGlassSection(title: text.sectionAbout) {
                        LiquidGlassRow(title: text.versionTitle) {
                            Text(state.appVersion)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        LiquidGlassRow(title: text.sourceTitle) {
                            Link("GitHub", destination: repoURL)
                                .buttonStyle(.glass)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 38)
                .padding(.bottom, 18)
            }
        }
        .controlSize(.small)
        .buttonStyle(.glass)
        .frame(width: LiquidGlassMetrics.settingsSize.width, height: LiquidGlassMetrics.settingsSize.height)
        .onAppear { NSApp.keyWindow?.title = text.settingsWindowTitle }
        .onChange(of: state.languagePreference) { _, _ in
            NSApp.keyWindow?.title = state.text.settingsWindowTitle
        }
    }
}
