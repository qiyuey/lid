import AppKit
import Darwin
import Foundation
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
            Image(state.showsActiveMenuBarIcon ? "MenubarLaptopActive" : "MenubarLaptop")
        }
        .menuBarExtraStyle(.window)
    }
}

private enum MaintenanceCommand {
    @MainActor
    static func runIfRequested() {
        if CommandLine.arguments.contains("--register-helper") {
            do {
                let helper = HelperManager()
                try helper.register()
                if waitForHelper(helper) {
                    print("Background helper registered and reachable.")
                } else {
                    fputs("Failed to reach background helper after registration.\n", stderr)
                    exit(EXIT_FAILURE)
                }
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Failed to register background helper: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        if CommandLine.arguments.contains("--unregister-helper") {
            do {
                let helper = HelperManager()
                try helper.unregister()
                if waitForHelperUnregistered(helper) {
                    print("Background helper unregistered.")
                } else {
                    fputs("Timed out waiting for background helper to unregister.\n", stderr)
                    exit(EXIT_FAILURE)
                }
                exit(EXIT_SUCCESS)
            } catch {
                fputs("Failed to unregister background helper: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }
    }

    @MainActor
    private static func waitForHelper(_ helper: HelperManager,
                                      maxAttempts: Int = 8,
                                      retryDelay: TimeInterval = 2) -> Bool {
        for attempt in 1...maxAttempts {
            if checkReachable(helper) {
                return true
            }
            if attempt < maxAttempts {
                pumpRunLoop(until: Date().addingTimeInterval(retryDelay))
            }
        }
        return false
    }

    @MainActor
    private static func checkReachable(_ helper: HelperManager) -> Bool {
        var reachable: Bool?
        helper.checkReachable { value in
            reachable = value
        }
        pumpRunLoop(until: Date().addingTimeInterval(6)) {
            reachable == nil
        }
        return reachable == true
    }

    @MainActor
    private static func waitForHelperUnregistered(_ helper: HelperManager,
                                                  maxAttempts: Int = 20,
                                                  retryDelay: TimeInterval = 0.5) -> Bool {
        for attempt in 1...maxAttempts {
            if !helper.isEnabled && !helper.requiresApproval {
                return true
            }
            if attempt < maxAttempts {
                pumpRunLoop(until: Date().addingTimeInterval(retryDelay))
            }
        }
        return !helper.isEnabled && !helper.requiresApproval
    }

    @MainActor
    private static func pumpRunLoop(until deadline: Date,
                                    while shouldContinue: () -> Bool = { true }) {
        while shouldContinue(), Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }
}
