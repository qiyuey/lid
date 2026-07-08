import AppKit

@MainActor
struct AlertPresenter {
    let text: AppStrings

    func presentToggleFailure(target: Bool, message: String) {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.toggleFailedTitle(target: target)
        alert.informativeText = message
        alert.addButton(withTitle: text.ok)
        alert.runModal()
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
