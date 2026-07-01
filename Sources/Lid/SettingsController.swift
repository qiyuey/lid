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
    private let windowSize = NSSize(width: 420, height: 500)

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
        win.title = state.text.settingsWindowTitle
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.isReleasedWhenClosed = false
        win.contentMinSize = windowSize
        win.setFrameAutosaveName("LidSettingsWindow.v3")
        win.setContentSize(windowSize)
        win.center()
        return win
    }
}
