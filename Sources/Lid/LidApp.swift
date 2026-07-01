import Darwin
import SwiftUI

@main
struct LidApp: App {
    @StateObject private var state: AppState
    @StateObject private var updater: UpdaterController

    init() {
        MaintenanceCommand.runIfRequested()
        _state = StateObject(wrappedValue: AppState())
        _updater = StateObject(wrappedValue: UpdaterController())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
        } label: {
            Image(state.isEnabled ? "MenubarLaptopActive" : "MenubarLaptop")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(state)
                .environmentObject(updater)
        }
    }
}

private enum MaintenanceCommand {
    @MainActor
    static func runIfRequested() {
        if CommandLine.arguments.contains("--register-helper") {
            do {
                try HelperManager().register()
                print("Background helper registration requested.")
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Failed to register background helper: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        if CommandLine.arguments.contains("--unregister-helper") {
            do {
                try HelperManager().unregister()
                print("Background helper unregistered.")
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Failed to unregister background helper: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
    }
}
