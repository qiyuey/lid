import Foundation

/// Battery safety policy (pure, unit-testable).
public enum SafetyPolicy {
    /// True when keep-awake should be auto-disabled to protect the battery:
    /// running on battery (not AC) at or below the threshold percent.
    public static func shouldDisableForBattery(_ info: BatteryInfo, threshold: Int) -> Bool {
        !info.onAC && info.percent <= threshold
    }
}
