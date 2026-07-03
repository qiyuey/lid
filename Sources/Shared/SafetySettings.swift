import Foundation

/// User-tunable safety preferences for keep-awake.
public struct SafetySettings: Equatable, Sendable {
    public var lowBatteryThreshold: Int
    public var onlyWhileCharging: Bool
    public var pauseOnHighThermal: Bool

    public static let `default` = SafetySettings(
        lowBatteryThreshold: 20,
        onlyWhileCharging: false,
        pauseOnHighThermal: true
    )

    public init(lowBatteryThreshold: Int,
                onlyWhileCharging: Bool,
                pauseOnHighThermal: Bool) {
        self.lowBatteryThreshold = lowBatteryThreshold
        self.onlyWhileCharging = onlyWhileCharging
        self.pauseOnHighThermal = pauseOnHighThermal
    }
}

/// Why keep-awake was (or should be) auto-disabled.
public enum SafetyReason: Equatable, Sendable {
    case highThermal
    case notCharging
    case lowBattery(Int)
}

/// Pure safety decision. No side effects, fully unit-testable.
public enum SafetyEvaluator {
    /// The reason keep-awake should be disabled given current conditions, or
    /// `nil` if it's safe to stay awake. Checked in priority order:
    /// thermal first (hardware protection), then charging policy, then battery.
    public static func reasonToDisable(battery: BatteryInfo,
                                       thermalSerious: Bool,
                                       settings: SafetySettings) -> SafetyReason? {
        if settings.pauseOnHighThermal && thermalSerious {
            return .highThermal
        }
        if settings.onlyWhileCharging && !battery.onAC {
            return .notCharging
        }
        if !battery.onAC && battery.percent <= settings.lowBatteryThreshold {
            return .lowBattery(battery.percent)
        }
        return nil
    }
}
