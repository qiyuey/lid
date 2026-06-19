import Foundation

/// Auto-off timer logic (pure, unit-testable).
///
/// Keep-awake is a convenience, not a safety mechanism, so the countdown lives
/// in the app — if the app dies the helper watchdog restores sleep anyway.
public enum AutoOff {
    /// Selectable durations (minutes). `0` means "no auto-off" (stay on until off).
    public static let presetMinutes = [15, 30, 60, 120, 240]

    /// When a timer started `minutes` ago from `start` should fire.
    public static func deadline(from start: Date, minutes: Int) -> Date {
        start.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    /// Seconds left until `deadline` (never negative).
    public static func remaining(deadline: Date, now: Date) -> TimeInterval {
        max(0, deadline.timeIntervalSince(now))
    }

    /// True once `now` has reached or passed `deadline`.
    public static func isExpired(deadline: Date, now: Date) -> Bool {
        now >= deadline
    }

    /// Countdown like `1:05:09` (with hours) or `9:42` (under an hour).
    public static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Menu label for a duration, e.g. `15 min`, `1 hour`, `2 hours`.
    public static func optionLabel(minutes: Int) -> String {
        guard minutes % 60 == 0 else { return "\(minutes) min" }
        let h = minutes / 60
        return h == 1 ? "1 hour" : "\(h) hours"
    }
}
