import Foundation

/// Pure parsers for `pmset` output. Kept free of side effects so they
/// can be unit-tested without touching real power management.
public enum PowerParsers {

    /// Parse `pmset -g` output and return whether the `SleepDisabled` flag is set.
    /// The relevant line looks like: ` SleepDisabled        1`
    public static func isSleepDisabled(pmsetG output: String) -> Bool {
        sleepDisabledValue(pmsetG: output) ?? false
    }

    /// Parse `pmset -g` output and return nil when the `SleepDisabled` line is absent.
    public static func sleepDisabledValue(pmsetG output: String) -> Bool? {
        for raw in output.split(separator: "\n") {
            let line = String(raw).lowercased()
            guard line.contains("sleepdisabled") else { continue }
            let remainder = line
                .replacingOccurrences(of: "sleepdisabled", with: "")
                .trimmingCharacters(in: .whitespaces)
            return remainder == "1"
        }
        return nil
    }
}
