import AppKit

@MainActor
struct AlertPresenter {
    let text: AppStrings

    func presentQuitAfterRestoreFailure(onQuitAnyway: () -> Void) {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.turnOffFailedTitle
        alert.informativeText = text.quitRestoreFailedText
        alert.addButton(withTitle: text.quitAnyway)
        alert.addButton(withTitle: text.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            onQuitAnyway()
        }
    }

    func confirmUninstallHelper() -> Bool {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.removeHelperTitle
        alert.informativeText = text.removeHelperText
        alert.addButton(withTitle: text.removeHelperButton)
        alert.addButton(withTitle: text.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    func presentHelperUninstallRestoreFailure(message: String) {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.removeHelperFailedTitle
        alert.informativeText = text.removeHelperFailedText(message)
        alert.addButton(withTitle: text.ok)
        alert.runModal()
    }

    func presentToggleFailure(target: Bool, message: String) {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.toggleFailedTitle(target: target)
        alert.informativeText = message
        alert.addButton(withTitle: text.ok)
        alert.runModal()
    }

    func presentHelperFailure(message: String, onReinstall: () -> Void) {
        activateApp()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = text.turnOnFailedTitle
        alert.informativeText = text.helperFailureText(message)
        alert.addButton(withTitle: text.reinstallHelper)
        alert.addButton(withTitle: text.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            onReinstall()
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}
