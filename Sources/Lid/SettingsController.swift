import AppKit
import SwiftUI

/// Hosts Settings in an AppKit window so the menu-bar app can reliably make it
/// key/frontmost. SwiftUI's `Settings` scene can show an inactive window for
/// `LSUIElement` apps when opened from a menu-bar extra.
@MainActor
final class SettingsController: ObservableObject {
    private let state: AppState
    private let updater: UpdaterController
    private var window: NSWindow?

    init(state: AppState, updater: UpdaterController) {
        self.state = state
        self.updater = updater
    }

    func show() {
        let win = window ?? makeWindow()
        window = win
        win.title = state.text.settingsWindowTitle

        NSApp.activate(ignoringOtherApps: true)
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])
        win.makeKeyAndOrderFront(nil)

        // Activation from an LSUIElement menu can settle one run-loop later.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
        }
    }

    private func makeWindow() -> NSWindow {
        let root = SettingsView()
            .environmentObject(state)
            .environmentObject(updater)
        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.configureLiquidGlassShell(
            title: state.text.settingsWindowTitle,
            size: LiquidGlassMetrics.settingsSize,
            autosaveName: "LidSettingsWindow.v4",
            allowsMiniaturize: true
        )
        win.center()
        return win
    }
}
