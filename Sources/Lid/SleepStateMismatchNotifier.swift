import Foundation
import OSLog
import UserNotifications

@MainActor
protocol SleepNotificationClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func remove(identifier: String)
}

@MainActor
final class SystemSleepNotificationClient: NSObject, SleepNotificationClient, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert])
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func remove(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

enum SleepNotificationOutcome: Equatable {
    case submitted
    case denied
    case failed(String)
    case cancelled
}

@MainActor
final class SleepStateMismatchNotifier {
    static let notificationIdentifier = "sleep-state-mismatch"

    private let client: any SleepNotificationClient
    private let logger = Logger(subsystem: "top.qiyuey.lid", category: "sleep-notification")
    private var reportTask: Task<SleepNotificationOutcome, Never>?

    init(client: any SleepNotificationClient = SystemSleepNotificationClient()) {
        self.client = client
    }

    @discardableResult
    func reportMismatch(target: Bool, text: AppStrings) -> Task<SleepNotificationOutcome, Never> {
        let previous = reportTask
        previous?.cancel()
        let task = Task { [client, logger] in
            // Serialize cleanup: an older add may finish after cancellation. It
            // must not remove a newer request that uses the same identifier.
            if let previous { _ = await previous.value }
            guard !Task.isCancelled else { return SleepNotificationOutcome.cancelled }
            do {
                let status = await client.authorizationStatus()
                guard !Task.isCancelled else { return .cancelled }
                logger.info("Notification authorization status: \(status.rawValue, privacy: .public)")
                if status == .notDetermined {
                    let granted = try await client.requestAuthorization()
                    guard !Task.isCancelled else { return .cancelled }
                    guard granted else {
                        logger.warning("Notification permission was not granted; mismatch remains in the menu.")
                        return .denied
                    }
                } else if status != .authorized && status != .provisional {
                    logger.warning("Notifications unavailable or denied; mismatch remains in the menu.")
                    return .denied
                }
                guard !Task.isCancelled else { return .cancelled }
                let content = UNMutableNotificationContent()
                content.title = text.sleepStateMismatchNotificationTitle
                content.body = text.sleepStateMismatch(target: target, actual: !target)
                try await client.add(UNNotificationRequest(
                    identifier: Self.notificationIdentifier, content: content, trigger: nil
                ))
                if Task.isCancelled {
                    client.remove(identifier: Self.notificationIdentifier)
                    return .cancelled
                }
                // Acceptance is not evidence that macOS displayed a banner.
                logger.info("Mismatch notification accepted by notification center.")
                return .submitted
            } catch {
                guard !Task.isCancelled else {
                    client.remove(identifier: Self.notificationIdentifier)
                    return .cancelled
                }
                let error = error as NSError
                let details = "\(error.domain) (\(error.code)): \(error.localizedDescription)"
                logger.error("Mismatch notification failed: \(details, privacy: .public)")
                return .failed(details)
            }
        }
        reportTask = task
        return task
    }

    func resolveMismatch() {
        reportTask?.cancel()
        // Keep the task so a subsequent report waits for any late add and cleanup.
        client.remove(identifier: Self.notificationIdentifier)
    }
}
