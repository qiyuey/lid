import Foundation

/// Identity of the privileged helper, derived from the owning app's bundle id so
/// that Debug (`.dev`) and Release builds get fully isolated daemons/services and
/// never collide. For app bundle id `top.qiyuey.lid` the helper id — which
/// doubles as its LaunchDaemon label, Mach service name, and the `.plist`
/// basename — is `top.qiyuey.lid.helper`.
public enum LidHelperIdentity {
    /// Label / Mach service name for a given app bundle id.
    public static func label(appBundleID: String) -> String { "\(appBundleID).helper" }

    /// Env var the generated LaunchDaemon plist passes to the (bundle-less) helper
    /// executable so it knows which Mach service to listen on without relying on
    /// an embedded bundle id.
    public static let machLabelEnvKey = "LID_MACH_LABEL"

    /// Fallback used only if the app bundle id / env var is unavailable.
    public static let fallbackLabel = "top.qiyuey.lid.helper"

    public static let allowedClientBundleIDEnvKey = "LID_ALLOWED_CLIENT_BUNDLE_ID"
    public static let allowedClientCertificateCommonNameEnvKey = "LID_ALLOWED_CLIENT_CERTIFICATE_CN"
    public static let allowedClientCertificateSHA1EnvKey = "LID_ALLOWED_CLIENT_CERTIFICATE_SHA1"
    public static let appVersionEnvKey = "LID_APP_VERSION"
    public static let appBuildEnvKey = "LID_APP_BUILD"
    public static let defaultSelfSignedCertificateCommonName = "Lid Local Self-Signed Code Signing"
    public static let helperVersion = 1

    public static func appBundleID(helperLabel: String) -> String {
        helperLabel.hasSuffix(".helper") ? String(helperLabel.dropLast(".helper".count)) : "top.qiyuey.lid"
    }

    public static func clientCodeSigningRequirement(
        appBundleID: String,
        certificateCommonName: String? = defaultSelfSignedCertificateCommonName,
        certificateSHA1: String? = nil
    ) -> String {
        let identifier = "identifier \"\(requirementLiteral(appBundleID))\""

        if let certificateSHA1, !certificateSHA1.isEmpty {
            return "\(identifier) and certificate leaf = H\"\(certificateHashLiteral(certificateSHA1))\""
        }

        let commonName = (certificateCommonName?.isEmpty == false)
            ? certificateCommonName!
            : defaultSelfSignedCertificateCommonName
        return "\(identifier) and certificate leaf[subject.CN] = \"\(requirementLiteral(commonName))\""
    }

    public static func versionString(bundle: Bundle,
                                     environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let version = environment[appVersionEnvKey]
            ?? bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        let build = environment[appBuildEnvKey]
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "unknown"
        return "helper-\(helperVersion) version-\(version) build-\(build)"
    }

    private static func requirementLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func certificateHashLiteral(_ value: String) -> String {
        let hash = value
            .filter { !$0.isWhitespace && $0 != ":" }
            .uppercased()
        let hexDigits = Set("0123456789ABCDEF")
        precondition(hash.count == 40 && hash.allSatisfy { hexDigits.contains($0) },
                     "certificate SHA-1 must contain 40 hex digits")
        return hash
    }
}

/// XPC interface implemented by the root helper and called by the app.
///
/// The helper runs as root (installed via `SMAppService`), so it can flip the
/// `SleepDisabled` flag without an admin prompt. A heartbeat watchdog inside the
/// helper auto-restores normal sleep if the app stops checking in, unless the
/// user explicitly asks Lid to continue after the app quits.
@objc public protocol LidHelperProtocol {
    /// Enable/disable lid-close sleep prevention. reply: (success, errorMessage?).
    func setKeepAwake(_ enabled: Bool, withReply reply: @escaping @Sendable (Bool, String?) -> Void)

    /// Enable/disable the heartbeat watchdog. reply: (success, errorMessage?).
    func setWatchdogEnabled(_ enabled: Bool, withReply reply: @escaping @Sendable (Bool, String?) -> Void)

    /// Read the current SleepDisabled flag. reply: (enabled).
    func getState(withReply reply: @escaping @Sendable (Bool) -> Void)

    /// Heartbeat from the app; resets the watchdog timer.
    func heartbeat(withReply reply: @escaping @Sendable (Bool) -> Void)

    /// Helper version string, for a connection sanity check.
    func version(withReply reply: @escaping @Sendable (String) -> Void)
}
