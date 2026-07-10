import Foundation
import UserNotifications

@MainActor
final class SleepStateMismatchNotifier {
    static let notificationIdentifier = "sleep-state-mismatch"

    private let center: UNUserNotificationCenter
    private var reportTask: Task<Void, Never>?

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func reportMismatch(target: Bool, text: AppStrings) {
        reportTask?.cancel()

        let content = UNMutableNotificationContent()
        content.title = text.sleepStateMismatchNotificationTitle
        content.body = text.sleepStateMismatch(target: target, actual: !target)

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: nil
        )

        reportTask = Task {
            do {
                let settings = await center.notificationSettings()
                guard !Task.isCancelled else { return }
                if settings.authorizationStatus == .notDetermined {
                    guard try await center.requestAuthorization(options: [.alert]) else { return }
                } else if settings.authorizationStatus != .authorized
                            && settings.authorizationStatus != .provisional {
                    return
                }
                guard !Task.isCancelled else { return }
                try await center.add(request)
                if Task.isCancelled {
                    center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
                }
            } catch {
                // Notification delivery must never interfere with power-state recovery.
            }
        }
    }

    func resolveMismatch() {
        reportTask?.cancel()
        reportTask = nil
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.notificationIdentifier])
    }
}
