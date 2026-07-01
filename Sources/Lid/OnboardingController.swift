import AppKit
import SwiftUI

/// Hosts the first-run onboarding flow in a standalone window.
///
/// Lid is an `LSUIElement` menu-bar app with no Dock presence, so auto-
/// presenting and focusing a window from a SwiftUI `Window` scene is unreliable.
/// A plain AppKit `NSWindow` wrapping the SwiftUI `OnboardingView` gives precise
/// control over showing, centering, focusing, and closing.
@MainActor
final class OnboardingController {
    private let windowSize = NSSize(
        width: LiquidGlassMetrics.onboardingSize.width,
        height: LiquidGlassMetrics.onboardingSize.height
    )

    private unowned let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    /// Show the window, building it on first use and reusing it afterwards so we
    /// never stack duplicates.
    func show() {
        if window == nil {
            let root = OnboardingView().environmentObject(state)
            let hosting = NSHostingController(rootView: root)
            let win = OnboardingWindow(
                contentRect: NSRect(origin: .zero, size: windowSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.contentViewController = hosting
            win.title = state.text.onboardingWindowTitle
            win.isMovableByWindowBackground = true
            win.isOpaque = false
            win.backgroundColor = .clear
            win.hasShadow = true
            win.isReleasedWhenClosed = false
            win.contentMinSize = windowSize
            win.setContentSize(windowSize)
            window = win
        }

        guard let window else { return }

        window.title = state.text.onboardingWindowTitle
        let screen = screenForPresentation(window)
        center(window, on: screen)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        center(window, on: screen)
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            self.center(window, on: screen)
        }
    }

    func close() {
        window?.orderOut(nil)
    }

    private func center(_ window: NSWindow, on screen: NSScreen) {
        let frame = screen.visibleFrame
        let size = window.frame.size
        let centeredFrame = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        window.setFrame(centeredFrame, display: true)
    }

    private func screenForPresentation(_ window: NSWindow) -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }) {
            return screen
        }
        return window.screen ?? NSScreen.main ?? NSScreen.screens.first!
    }
}

private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
