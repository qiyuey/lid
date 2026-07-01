import Foundation

/// Narrow fallback for inspecting and restoring the macOS `SleepDisabled` flag.
///
/// Enabling lid sleep prevention should go through `HelperManager` and the root
/// helper. This type exists only to read the current flag and to restore normal
/// sleep as a last resort when the helper cannot do it during removal or quit.
struct EmergencySleepRestorer {

    /// Read the current `SleepDisabled` flag from `pmset -g`.
    func isSleepDisabled() -> Bool {
        guard let out = Shell.capture("/usr/bin/pmset", ["-g"]) else { return false }
        return PowerParsers.isSleepDisabled(pmsetG: out)
    }

    /// Clear the flag. Throws with the underlying error message on failure
    /// (including the user cancelling the admin prompt).
    func restoreNormalSleep() throws {
        let script = "do shell script \"/usr/bin/pmset -a disablesleep 0\" with administrator privileges"

        let result = ProcessRunner.run("/usr/bin/osascript", ["-e", script], timeout: 30)
        if !result.succeeded {
            let msg = result.timedOut
                ? "Authorization timed out."
                : result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "Lid.EmergencySleepRestorer",
                code: Int(result.exitCode),
                userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "Authorization cancelled." : msg]
            )
        }
    }
}
