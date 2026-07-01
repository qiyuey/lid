import Foundation

@MainActor
final class AutoOffController {
    private let store: SettingsStore
    private var timer: Timer?

    private(set) var minutes: Int
    private(set) var deadline: Date?
    private(set) var remaining = ""

    var onChange: (@MainActor @Sendable () -> Void)?
    var onExpired: (@MainActor @Sendable (Int) -> Void)?

    init(store: SettingsStore) {
        self.store = store
        minutes = store.loadAutoOffMinutes()
    }

    func setMinutes(_ minutes: Int, isEnabled: Bool) {
        self.minutes = minutes
        store.saveAutoOffMinutes(minutes)
        update(for: isEnabled)
    }

    func update(for enabled: Bool) {
        if enabled {
            arm()
        } else {
            cancel()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    private func arm() {
        cancel()
        guard minutes > 0 else { return }
        deadline = AutoOff.deadline(from: Date(), minutes: minutes)
        refreshRemaining()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        notify()
    }

    private func cancel() {
        timer?.invalidate()
        timer = nil
        deadline = nil
        remaining = ""
        notify()
    }

    private func tick() {
        guard let deadline else { return }
        if AutoOff.isExpired(deadline: deadline, now: Date()) {
            let elapsed = minutes
            cancel()
            onExpired?(elapsed)
        } else {
            refreshRemaining()
            notify()
        }
    }

    private func refreshRemaining() {
        guard let deadline else {
            remaining = ""
            return
        }
        remaining = AutoOff.formatCountdown(AutoOff.remaining(deadline: deadline, now: Date()))
    }

    private func notify() {
        onChange?()
    }
}
