import Foundation

/// Controls the macOS `SleepDisabled` flag (IOPMrootDomain).
///
/// This is the **fallback** path, used only when the privileged helper isn't
/// installed: it shells out to `pmset -a disablesleep` via `osascript` with
/// administrator privileges, so toggling prompts for the admin password.
///
/// The primary path is `HelperManager`, which sets the flag over XPC through a
/// root helper installed via `SMAppService` — password-less, plus a heartbeat
/// watchdog that auto-clears the flag if the app dies.
struct PowerManager {

    /// Read the current `SleepDisabled` flag from `pmset -g`.
    func isSleepDisabled() -> Bool {
        guard let out = Shell.capture("/usr/bin/pmset", ["-g"]) else { return false }
        return PowerParsers.isSleepDisabled(pmsetG: out)
    }

    /// Set or clear the flag. Throws with the underlying error message on failure
    /// (including the user cancelling the admin prompt).
    func setSleepDisabled(_ enabled: Bool) throws {
        let value = enabled ? "1" : "0"
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"

        let result = ProcessRunner.run("/usr/bin/osascript", ["-e", script], timeout: 30)
        if !result.succeeded {
            let msg = result.timedOut
                ? "Authorization timed out."
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "Lid.PowerManager",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "Authorization cancelled." : msg]
            )
        }
    }
}
