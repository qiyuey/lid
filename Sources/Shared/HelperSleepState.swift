import Foundation

/// User-visible sleep-prevention state owned and persisted by the privileged helper.
public struct HelperSleepState: Codable, Equatable, Sendable {
    public var sleepPreventionEnabled: Bool

    public static let `default` = HelperSleepState(sleepPreventionEnabled: false)

    public init(sleepPreventionEnabled: Bool) {
        self.sleepPreventionEnabled = sleepPreventionEnabled
    }
}
