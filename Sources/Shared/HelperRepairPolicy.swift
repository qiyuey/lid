import Foundation

/// Small guard around automatic helper repair so transient XPC failures do not
/// trigger repeated unregister/register cycles.
public struct AutomaticHelperRepairGate: Equatable, Sendable {
    public let cooldown: TimeInterval
    private var repairInProgress = false
    private var lastRepairAt: Date?

    public var isRepairInProgress: Bool {
        repairInProgress
    }

    public init(cooldown: TimeInterval) {
        self.cooldown = cooldown
    }

    public mutating func beginIfAllowed(now: Date,
                                        helperInstalled: Bool,
                                        helperNeedsApproval: Bool) -> Bool {
        guard helperInstalled, !helperNeedsApproval, !repairInProgress else { return false }
        if let lastRepairAt, now.timeIntervalSince(lastRepairAt) < cooldown {
            return false
        }

        repairInProgress = true
        lastRepairAt = now
        return true
    }

    public mutating func finish() {
        repairInProgress = false
    }
}
