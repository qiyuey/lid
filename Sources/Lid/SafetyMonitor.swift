import Foundation

struct SafetyMonitor {
    var battery: BatteryReading
    var thermalState: () -> ProcessInfo.ThermalState

    init(battery: BatteryReading,
         thermalState: @escaping () -> ProcessInfo.ThermalState = { ProcessInfo.processInfo.thermalState }) {
        self.battery = battery
        self.thermalState = thermalState
    }

    func reasonToDisable(settings: SafetySettings) -> SafetyReason? {
        SafetyEvaluator.reasonToDisable(
            battery: battery.read(),
            thermalSerious: thermalSerious,
            settings: settings
        )
    }

    private var thermalSerious: Bool {
        let state = thermalState()
        return state == .serious || state == .critical
    }
}
