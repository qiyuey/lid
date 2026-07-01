import AppKit
import SwiftUI

/// Hosts the first-run onboarding flow in a standalone window.
///
/// Lid is an `LSUIElement` menu-bar app with no Dock presence, so auto-
/// presenting and focusing a window from a SwiftUI `Window` scene is unreliable.
/// A plain AppKit `NSWindow` wrapping the SwiftUI `OnboardingView` gives precise
/// control over showing, centering, focusing, and closing — and mirrors how the
/// Settings window already surfaces.
@MainActor
final class OnboardingController {
    private weak var state: AppState?
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    /// Show the window, building it on first use and reusing it afterwards so we
    /// never stack duplicates.
    func show() {
        guard let state else { return }

        if window == nil {
            let root = OnboardingView().environmentObject(state)
            let hosting = NSHostingController(rootView: root)
            let win = NSWindow(contentViewController: hosting)
            win.title = state.text.onboardingWindowTitle
            win.styleMask = [.titled, .closable, .fullSizeContentView]
            win.titleVisibility = .hidden
            win.titlebarAppearsTransparent = true
            win.isMovableByWindowBackground = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.isReleasedWhenClosed = false
            win.contentMinSize = NSSize(width: 500, height: 540)
            win.center()
            window = win
        }

        window?.title = state.text.onboardingWindowTitle
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.center()
    }

    func close() {
        window?.close()
    }
}
