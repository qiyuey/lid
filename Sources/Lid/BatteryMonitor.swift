import Foundation
import IOKit.ps

protocol BatteryReading {
    func read() -> BatteryInfo
}

/// Reads battery level + power source through IOKit and emits change
/// notifications from the system power-source run loop source.
final class BatteryMonitor: BatteryReading {
    private var runLoopSource: CFRunLoopSource?
    private var onChange: ((BatteryInfo) -> Void)?

    func read() -> BatteryInfo {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            if let present = description[kIOPSIsPresentKey] as? Bool, !present {
                continue
            }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCapacity = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let rawPercent = maxCapacity > 0
                ? Int((Double(current) / Double(maxCapacity) * 100).rounded())
                : current
            let percent = min(100, max(0, rawPercent))
            let state = description[kIOPSPowerSourceStateKey] as? String
            return BatteryInfo(percent: percent, onAC: state == kIOPSACPowerValue)
        }

        return BatteryInfo(percent: 0, onAC: false)
    }

    func start(onChange: @escaping (BatteryInfo) -> Void) {
        self.onChange = onChange
        guard runLoopSource == nil else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.emitChange()
        }, context)?.takeRetainedValue() else {
            return
        }

        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = nil
        onChange = nil
    }

    deinit {
        stop()
    }

    private func emitChange() {
        onChange?(read())
    }
}
