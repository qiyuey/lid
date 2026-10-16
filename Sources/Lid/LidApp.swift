import AppKit
import Foundation
import SwiftUI

@main
enum LidEntryPoint {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--diagnose-notifications") {
            Task { @MainActor in
                let code = await NotificationDiagnostic.run()
                exit(code)
            }
            dispatchMain()
        }
        LidApp.main()
    }
}

struct LidApp: App {
    @StateObject private var state: AppState
    @StateObject private var updater: UpdaterController

    init() {
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
            Image(state.showsActiveMenuBarIcon ? "MenubarLaptopActive" : "MenubarLaptop")
        }
        .menuBarExtraStyle(.window)
    }
}
