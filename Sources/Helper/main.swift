import Foundation
import OSLog

// Entry point for the privileged helper (a LaunchDaemon running as root).
// It listens on a Mach service and serves LidHelperProtocol over XPC. The
// Mach service name is handed in by the LaunchDaemon plist (per build config), so
// the same binary serves both the Release and the `.dev` daemons.
let env = ProcessInfo.processInfo.environment
let machLabel = env[LidHelperIdentity.machLabelEnvKey] ?? LidHelperIdentity.fallbackLabel
let appBundleID = env[LidHelperIdentity.allowedClientBundleIDEnvKey] ?? LidHelperIdentity.appBundleID(helperLabel: machLabel)
let certificateCommonName = env[LidHelperIdentity.allowedClientCertificateCommonNameEnvKey].flatMap { value in
    value.isEmpty ? nil : value
} ?? LidHelperIdentity.defaultSelfSignedCertificateCommonName
let certificateSHA1 = env[LidHelperIdentity.allowedClientCertificateSHA1EnvKey].flatMap { value in
    value.isEmpty ? nil : value
}
let clientRequirement = LidHelperIdentity.clientCodeSigningRequirement(appBundleID: appBundleID,
                                                                       certificateCommonName: certificateCommonName,
                                                                       certificateSHA1: certificateSHA1)
let logger = Logger(subsystem: "top.qiyuey.lid", category: "helper-main")
logger.info("Starting helper for \(machLabel, privacy: .public)")

let delegate = HelperListenerDelegate(clientRequirement: clientRequirement)
let listener = NSXPCListener(machServiceName: machLabel)
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
