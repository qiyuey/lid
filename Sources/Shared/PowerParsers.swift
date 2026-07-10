import Foundation

/// Pure parsers for `pmset` output. Kept free of side effects so they
/// can be unit-tested without touching real power management.
public enum PowerParsers {
    /// Parse `pmset -g` output and return nil unless exactly one valid
    /// `SleepDisabled 0|1` line is present.
    public static func sleepDisabledValue(pmsetG output: String) -> Bool? {
        var parsedValue: Bool?
        var foundValue = false

        for raw in output.split(separator: "\n") {
            let fields = raw.split(whereSeparator: { $0.isWhitespace })
            guard fields.first?.lowercased() == "sleepdisabled" else { continue }
            guard !foundValue, fields.count == 2 else { return nil }

            switch fields[1] {
            case "0":
                parsedValue = false
            case "1":
                parsedValue = true
            default:
                return nil
            }
            foundValue = true
        }

        return parsedValue
    }
}
