import XCTest
import UserNotifications

@MainActor
final class SleepStateMismatchNotifierTests: XCTestCase {
    private let text = AppStrings(language: .english)

    func testAuthorizedNotificationIsSubmittedWithoutPrompt() async {
        let client = StubNotificationClient()
        let notifier = SleepStateMismatchNotifier(client: client)
        let result = await notifier.reportMismatch(target: true, text: text).value
        XCTAssertEqual(result, .submitted)
        XCTAssertEqual(client.prompts, 0)
        XCTAssertEqual(client.requests.first?.content.body, text.sleepStateMismatch(target: true, actual: false))
    }

    func testDeniedPermissionIsRespectedWithoutFallbackOrPrompt() async {
        let client = StubNotificationClient()
        client.status = .denied
        let result = await SleepStateMismatchNotifier(client: client).reportMismatch(target: true, text: text).value
        XCTAssertEqual(result, .denied)
        XCTAssertEqual(client.prompts, 0)
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testFirstPermissionRequestAndProvisionalPermission() async {
        for status in [UNAuthorizationStatus.notDetermined, .provisional] {
            let client = StubNotificationClient()
            client.status = status
            let result = await SleepStateMismatchNotifier(client: client).reportMismatch(target: false, text: text).value
            XCTAssertEqual(result, .submitted)
            XCTAssertEqual(client.prompts, status == .notDetermined ? 1 : 0)
        }
    }

    func testPermissionRejectionDoesNotSubmit() async {
        let client = StubNotificationClient()
        client.status = .notDetermined
        client.granted = false
        let result = await SleepStateMismatchNotifier(client: client).reportMismatch(target: true, text: text).value
        XCTAssertEqual(result, .denied)
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testAuthorizationAndSubmissionErrorsAreReported() async {
        for status in [UNAuthorizationStatus.notDetermined, .authorized] {
            let client = StubNotificationClient()
            client.status = status
            client.failure = NSError(domain: "UNErrorDomain", code: 1)
            let result = await SleepStateMismatchNotifier(client: client).reportMismatch(target: true, text: text).value
            guard case .failed(let details) = result else { return XCTFail("Expected failure, got \(result)") }
            XCTAssertTrue(details.contains("UNErrorDomain (1)"))
        }
    }

    func testResolutionWhileAddIsPendingRemovesLateNotification() async {
        let client = StubNotificationClient()
        client.pauseAdd = true
        let notifier = SleepStateMismatchNotifier(client: client)
        let task = notifier.reportMismatch(target: true, text: text)
        await client.waitForAdd()
        notifier.resolveMismatch()
        client.resumeAdd()
        let result = await task.value
        XCTAssertEqual(result, .cancelled)
        XCTAssertTrue(client.visible.isEmpty)
    }

    func testNewReportWaitsForOldCleanupWithoutDeletingNewNotification() async {
        let client = StubNotificationClient()
        client.pauseAdd = true
        let notifier = SleepStateMismatchNotifier(client: client)
        let old = notifier.reportMismatch(target: true, text: text)
        await client.waitForAdd()
        let new = notifier.reportMismatch(target: false, text: text)
        client.pauseAdd = false
        client.resumeAdd()
        let oldResult = await old.value
        let newResult = await new.value
        XCTAssertEqual(oldResult, .cancelled)
        XCTAssertEqual(newResult, .submitted)
        XCTAssertEqual(client.visible.values.first?.content.body, text.sleepStateMismatch(target: false, actual: true))
        XCTAssertEqual(client.visible.count, 1)
    }
}

@MainActor
private final class StubNotificationClient: SleepNotificationClient {
    var status: UNAuthorizationStatus = .authorized
    var granted = true
    var failure: NSError?
    var prompts = 0
    var requests: [UNNotificationRequest] = []
    var visible: [String: UNNotificationRequest] = [:]
    var pauseAdd = false
    private var pendingAdd: CheckedContinuation<Void, Never>?
    private var addStarted: CheckedContinuation<Void, Never>?

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async throws -> Bool {
        prompts += 1
        if let failure { throw failure }
        return granted
    }
    func add(_ request: UNNotificationRequest) async throws {
        requests.append(request)
        if let failure { throw failure }
        if pauseAdd {
            await withCheckedContinuation { pendingAdd = $0; addStarted?.resume(); addStarted = nil }
        }
        visible[request.identifier] = request
    }
    func remove(identifier: String) { visible.removeValue(forKey: identifier) }
    func waitForAdd() async {
        if pendingAdd != nil { return }
        await withCheckedContinuation { addStarted = $0 }
    }
    func resumeAdd() { pendingAdd?.resume(); pendingAdd = nil }
}
