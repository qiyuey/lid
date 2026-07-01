import Foundation

/// Identity of the privileged helper, derived from the owning app's bundle id so
/// that Debug (`.dev`) and Release builds get fully isolated daemons/services and
/// never collide. For app bundle id `com.qiyuey.lid` the helper id — which
/// doubles as its LaunchDaemon label, Mach service name, and the `.plist`
/// basename — is `com.qiyuey.lid.helper`.
public enum LidHelperIdentity {
    /// Label / Mach service name for a given app bundle id.
    public static func label(appBundleID: String) -> String { "\(appBundleID).helper" }

    /// Env var the generated LaunchDaemon plist passes to the (bundle-less) helper
    /// executable so it knows which Mach service to listen on without relying on
    /// an embedded bundle id.
    public static let machLabelEnvKey = "LID_MACH_LABEL"

    /// Fallback used only if the app bundle id / env var is unavailable.
    public static let fallbackLabel = "com.qiyuey.lid.helper"

    public static let allowedClientBundleIDEnvKey = "LID_ALLOWED_CLIENT_BUNDLE_ID"
    public static let allowedTeamIDEnvKey = "LID_ALLOWED_TEAM_ID"
    public static let appVersionEnvKey = "LID_APP_VERSION"
    public static let appBuildEnvKey = "LID_APP_BUILD"
    public static let defaultTeamIdentifier = "7T4ZKYBB6Z"
    public static let protocolVersion = 1

    public static func appBundleID(helperLabel: String) -> String {
        helperLabel.hasSuffix(".helper") ? String(helperLabel.dropLast(".helper".count)) : "com.qiyuey.lid"
    }

    public static func clientCodeSigningRequirement(appBundleID: String, teamID: String) -> String {
        "identifier \"\(requirementLiteral(appBundleID))\" and anchor apple generic and certificate leaf[subject.OU] = \"\(requirementLiteral(teamID))\""
    }

    public static func versionString(bundle: Bundle,
                                     environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let version = environment[appVersionEnvKey]
            ?? bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        let build = environment[appBuildEnvKey]
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "unknown"
        return "protocol-\(protocolVersion) version-\(version) build-\(build)"
    }

    private static func requirementLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// XPC interface implemented by the root helper and called by the app.
///
/// The helper runs as root (installed via `SMAppService`), so it can flip the
/// `SleepDisabled` flag without an admin prompt. A heartbeat watchdog inside the
/// helper auto-restores normal sleep if the app stops checking in — so the Mac
/// can never get stuck awake if the app crashes or is force-quit.
@objc public protocol LidHelperProtocol {
    /// Enable/disable lid-close sleep prevention. reply: (success, errorMessage?).
    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping (Bool, String?) -> Void)

    /// Read the current SleepDisabled flag. reply: (enabled).
    func getState(withReply reply: @escaping (Bool) -> Void)

    /// Heartbeat from the app; resets the watchdog timer.
    func heartbeat(withReply reply: @escaping (Bool) -> Void)

    /// Helper version string, for a connection sanity check.
    func version(withReply reply: @escaping (String) -> Void)
}
