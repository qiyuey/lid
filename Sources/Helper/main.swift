import Foundation

// Entry point for the privileged helper (a LaunchDaemon running as root).
// It listens on a Mach service and serves LidHelperProtocol over XPC. The
// Mach service name is handed in by the LaunchDaemon plist (per build config), so
// the same binary serves both the Release and the `.dev` daemons.
let env = ProcessInfo.processInfo.environment
let machLabel = env[LidHelperIdentity.machLabelEnvKey] ?? LidHelperIdentity.fallbackLabel
let appBundleID = env[LidHelperIdentity.allowedClientBundleIDEnvKey] ?? LidHelperIdentity.appBundleID(helperLabel: machLabel)
let teamID = env[LidHelperIdentity.allowedTeamIDEnvKey] ?? LidHelperIdentity.defaultTeamIdentifier
let clientRequirement = LidHelperIdentity.clientCodeSigningRequirement(appBundleID: appBundleID, teamID: teamID)

let delegate = HelperListenerDelegate(clientRequirement: clientRequirement)
let listener = NSXPCListener(machServiceName: machLabel)
listener.setConnectionCodeSigningRequirement(clientRequirement)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()
