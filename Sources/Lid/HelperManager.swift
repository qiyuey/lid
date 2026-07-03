import AppKit
import Foundation
import OSLog
import ServiceManagement

/// Manages the privileged helper: registration via SMAppService and XPC calls.
/// All completion handlers are delivered on the main queue.
@MainActor
final class HelperManager {
    private var connection: NSXPCConnection?
    private let logger = Logger(subsystem: "top.qiyuey.lid", category: "helper-manager")
    private enum Timing {
        static let reregisterSettleDelay: UInt64 = 500_000_000
        static let defaultXPCTimeout: TimeInterval = 6
        static let reachabilityTimeout: TimeInterval = 5
    }

    /// Helper label / Mach service name, derived from this app's bundle id so the
    /// `.dev` build talks to its own daemon and never the Release one.
    private var helperLabel: String {
        LidHelperIdentity.label(appBundleID: Bundle.main.bundleIdentifier ?? "top.qiyuey.lid")
    }

    /// The generated LaunchDaemon plist embedded at `Contents/Library/LaunchDaemons`.
    private var plistName: String { "\(helperLabel).plist" }

    private var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }

    // MARK: Registration

    var isEnabled: Bool { service.status == .enabled }
    var requiresApproval: Bool { service.status == .requiresApproval }

    /// Register the daemon. Throws if registration fails outright. After this,
    /// `status` may be `.requiresApproval` until the user approves in Settings.
    func register() throws { try service.register() }

    func unregister() throws { try service.unregister() }

    func unregister(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        let svc = service
        connection?.invalidate()
        connection = nil
        svc.unregister { error in
            let message = error?.localizedDescription
            Task { @MainActor in
                completion(message)
            }
        }
    }

    /// Rebuild the registration from scratch so launchd picks up the current
    /// helper binary and launch constraints. A plain re-`register()` does not
    /// reliably clear stale records — only a full unregister followed by a fresh
    /// register does.
    ///
    /// `unregister` is asynchronous, so we register from its completion (a
    /// register issued immediately after fails with the unregister still settling).
    /// `completion` is delivered on the main queue with any registration error.
    func reregister(completion: @escaping @MainActor @Sendable (String?) -> Void) {
        let svc = service
        connection?.invalidate()
        connection = nil
        svc.unregister { [weak self] _ in
            // Give launchd/BTM a moment to drop the old job before re-adding it.
            Task { @MainActor in
                guard let self else {
                    completion(nil)
                    return
                }
                try? await Task.sleep(nanoseconds: Timing.reregisterSettleDelay)
                do {
                    try self.service.register()
                    completion(nil)
                } catch {
                    completion(error.localizedDescription)
                }
            }
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
        // Fallback: the SMAppService call silently no-ops for LSUIElement apps
        // or when System Settings is already running in the background, so also
        // open the Login Items pane by URL, which brings Settings to the front.
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: XPC

    private func connect() -> NSXPCConnection {
        if let existing = connection { return existing }
        logger.info("Creating helper XPC connection for \(self.helperLabel, privacy: .public)")
        let conn = NSXPCConnection(machServiceName: helperLabel, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: LidHelperProtocol.self)
        conn.invalidationHandler = { [weak self, weak conn] in
            Task { @MainActor in
                guard let conn else { return }
                self?.dropConnection(conn)
            }
        }
        conn.interruptionHandler = { [weak self, weak conn] in
            Task { @MainActor in
                guard let conn else { return }
                self?.dropConnection(conn)
            }
        }
        conn.resume()
        connection = conn
        return conn
    }

    private func dropConnection(_ conn: NSXPCConnection) {
        if connection === conn {
            logger.info("Dropping interrupted helper XPC connection")
            connection = nil
        }
    }

    private func resetConnection() {
        if connection != nil {
            logger.info("Resetting helper XPC connection")
        }
        connection?.invalidate()
        connection = nil
    }

    private func remote(_ onError: @escaping @MainActor @Sendable (String) -> Void) -> LidHelperProtocol? {
        let errorHandler: @Sendable (Error) -> Void = { [weak self] error in
            let message = error.localizedDescription
            Task { @MainActor in
                self?.logger.error("Helper XPC error: \(message, privacy: .public)")
                self?.resetConnection()
                onError(message)
            }
        }
        let proxy = connect().remoteObjectProxyWithErrorHandler(errorHandler)
        return proxy as? LidHelperProtocol
    }

    func setKeepAwake(_ enabled: Bool, completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        callWithTimeout(completion: completion) { proxy, done in
            proxy.setKeepAwake(enabled) { ok, err in done(ok, err) }
        }
    }

    func getState(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        getStateResult { value, _ in completion(value) }
    }

    func getStateResult(completion: @escaping @MainActor @Sendable (Bool, String?) -> Void) {
        callWithTimeout(completion: completion) { proxy, done in
            proxy.getState { value in done(value, nil) }
        }
    }

    /// True if the daemon answers with the app version/build embedded in this
    /// app bundle, false if it can't be reached or belongs to another build.
    /// Used to detect registered-but-unlaunchable or stale helpers.
    func checkReachable(completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let expectedVersion = LidHelperIdentity.versionString(bundle: .main, environment: [:])
        callWithTimeout(timeout: Timing.reachabilityTimeout, completion: { ok, _ in completion(ok) }) { proxy, done in
            proxy.version { version in
                done(version == expectedVersion, nil)
            }
        }
    }

    /// Run a single XPC call, guaranteeing `completion` fires exactly once on the
    /// main queue. If the daemon never replies — e.g. it fails to launch after an
    /// repair, so neither the reply nor the connection's error handler ever fires
    /// — a timeout reports failure instead of leaving the UI hung and silent.
    private func callWithTimeout(timeout: TimeInterval = Timing.defaultXPCTimeout,
                                 completion: @escaping @MainActor @Sendable (Bool, String?) -> Void,
                                 _ body: (LidHelperProtocol, @escaping @Sendable (Bool, String?) -> Void) -> Void) {
        let gate = CompletionGate()
        let finish: @Sendable (Bool, String?) -> Void = { ok, err in
            Task { @MainActor in
                guard gate.claim() else { return }
                completion(ok, err)
            }
        }
        guard let proxy = remote({ finish(false, $0) }) else {
            finish(false, "No helper connection")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            Task { @MainActor in
                guard gate.claim() else { return }
                self?.logger.error("Helper XPC call timed out after \(timeout, privacy: .public)s")
                self?.resetConnection()
                completion(false, "The background helper isn’t responding.")
            }
        }
        body(proxy) { ok, err in finish(ok, err) }
    }
}

extension HelperManager: HelperManaging {}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !finished else { return false }
        finished = true
        return true
    }
}
