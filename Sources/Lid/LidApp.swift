import Darwin
import SwiftUI

@main
struct LidApp: App {
    @StateObject private var state: AppState
    @StateObject private var updater: UpdaterController

    init() {
        MaintenanceCommand.runIfRequested()
        let appState = AppState()
        let updaterController = UpdaterController()
        _state = StateObject(wrappedValue: appState)
        _updater = StateObject(wrappedValue: updaterController)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(state)
                .environmentObject(updater)
        } label: {
            Image(state.isEnabled ? "MenubarLaptopActive" : "MenubarLaptop")
        }
        .menuBarExtraStyle(.window)
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
