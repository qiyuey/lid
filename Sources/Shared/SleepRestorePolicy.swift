import Foundation

/// Only confirmed settings become the desired state. Failed or cancelled writes
/// retain the last automatic attempt so periodic reads cannot cause prompt storms.
struct SleepRestorePolicy {
    private(set) var desired: Bool?
    private var lastAttempt: Date?
    private let retryInterval: TimeInterval = 10 * 60

    init(desired: Bool? = nil) {
        self.desired = desired
    }

    mutating func confirm(_ value: Bool) {
        desired = value
        lastAttempt = nil
    }

    mutating func observe(_ value: Bool) {
        if desired == value { lastAttempt = nil }
    }

    mutating func nextRestore(observed: Bool, isChanging: Bool, now: Date) -> Bool? {
        guard !isChanging, let desired, desired != observed else { return nil }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < retryInterval { return nil }
        lastAttempt = now
        return desired
    }
}
