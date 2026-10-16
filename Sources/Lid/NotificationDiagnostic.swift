import Foundation
import UserNotifications

/// Explicit developer diagnostic, before AppState starts. Never reads or changes
/// power settings, user defaults, login items, or updater state.
@MainActor
enum NotificationDiagnostic {
    static func run() async -> Int32 {
        let center = UNUserNotificationCenter.current()
        let identifier = "lid-notification-diagnostic-\(UUID().uuidString)"
        let client = SystemSleepNotificationClient(center: center)
        defer { client.remove(identifier: identifier) }
        let before = await client.authorizationStatus()
        print("bundle=\(Bundle.main.bundleIdentifier ?? "unknown") authorization=\(before.rawValue)")
        do {
            if before == .notDetermined {
                let granted = try await client.requestAuthorization()
                print("authorizationGranted=\(granted)")
            }
            let after = await client.authorizationStatus()
            guard after == .authorized || after == .provisional else {
                print("result=unavailable authorization=\(after.rawValue); no notification submitted")
                return 2
            }
            let content = UNMutableNotificationContent()
            content.title = "Lid notification test"
            content.body = "Diagnostic only. Your sleep settings have not changed."
            try await client.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
            print("result=accepted (does not confirm a visible banner)")
            try await Task.sleep(for: .seconds(3))
            let delivered = await center.deliveredNotifications().contains { $0.request.identifier == identifier }
            print("presentInNotificationCenter=\(delivered)")
            return delivered ? 0 : 3
        } catch {
            let error = error as NSError
            print("result=failed domain=\(error.domain) code=\(error.code) message=\(error.localizedDescription)")
            return 1
        }
    }
}
