import AppKit
import Foundation
import SwiftUI

@main
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
