import XCTest
@testable import CoranNative

@MainActor private final class ReminderProbe: LocalReminderGateway {
    var permission = true
    var requests: [String: NativeReminder] = [:]
    var removed: [String] = []
    var clears = 0
    var suspendNextAdd = false
    var continuation: CheckedContinuation<Void, Never>?
    func allowed() async -> Bool { permission }
    func authorize() async throws -> Bool { permission }
    func pendingIDs() async -> [String] { Array(requests.keys) + ["unrelated.notification"] }
    func remove(_ ids: [String]) { removed += ids; for id in ids { requests.removeValue(forKey: id) } }
    func clearDelivered() async { clears += 1 }
    func add(_ reminder: NativeReminder) async throws {
        if suspendNextAdd { suspendNextAdd = false; await withCheckedContinuation { continuation = $0 } }
        requests[reminder.id] = reminder
    }
}

@MainActor final class ReminderTests: XCTestCase {
    func testPreferencesReuseSharedKeysAndPreserveOtherNotifications() {
        let state: JSONValue = .object(["notifications": .object(["messages": .bool(false), "learning": .bool(true), "nativeReminderTimes": .object(["future": .string("kept")])])])
        var settings = ReminderSettings.load(state); XCTAssertTrue(settings.learning); XCTAssertFalse(settings.revision)
        settings.learningHour = 8; settings.learningMinute = 35; settings.revision = true
        let updated = settings.applying(to: state, at: "2026-10-07T12:00:00.000Z")
        XCTAssertEqual(updated["notifications"]["messages"], .bool(false)); XCTAssertEqual(updated["notifications"]["nativeReminderTimes"]["future"].string, "kept")
        XCTAssertEqual(ReminderSettings.load(updated), settings)
        XCTAssertEqual(settings.applying(to: updated, at: "2026-10-06T12:00:00.000Z"), updated)
        settings.learningHour = 24; XCTAssertEqual(settings.applying(to: state, at: "2026-10-08T12:00:00.000Z"), state)
    }
    func testSchedulingRemainsDeduplicatedAndLogoutRemovesOnlyNativeReminders() async {
        let gateway = ReminderProbe(), service = LocalReminderService(gateway: gateway), owner = UUID()
        var settings = ReminderSettings(); settings.learning = true; settings.revision = true
        service.update(owner: owner, settings: settings); await service.waitForUpdates()
        service.update(owner: owner, settings: settings, force: true); await service.waitForUpdates()
        XCTAssertEqual(gateway.requests.count, 2); XCTAssertEqual(Set(gateway.requests.values.map(\.owner)), [owner])
        service.update(owner: nil, settings: ReminderSettings()); await service.waitForUpdates()
        XCTAssertTrue(gateway.requests.isEmpty); XCTAssertFalse(gateway.removed.contains("unrelated.notification"))
        XCTAssertGreaterThan(gateway.clears, 0)
    }
    func testAccountSwitchDuringSchedulingCannotLeavePreviousUsersReminder() async {
        let gateway = ReminderProbe(), service = LocalReminderService(gateway: gateway), first = UUID(), second = UUID()
        var learning = ReminderSettings(); learning.learning = true
        gateway.suspendNextAdd = true; service.update(owner: first, settings: learning)
        while gateway.continuation == nil { await Task.yield() }
        var revision = ReminderSettings(); revision.revision = true
        service.update(owner: second, settings: revision)
        gateway.continuation?.resume(); await service.waitForUpdates()
        XCTAssertEqual(gateway.requests.count, 1); XCTAssertEqual(gateway.requests.values.first?.owner, second)
        XCTAssertEqual(gateway.requests.values.first?.kind, "revision-reminder")
    }
    func testDeniedPermissionDoesNotScheduleAndNotificationRoutingChecksAccount() async {
        let gateway = ReminderProbe(), service = LocalReminderService(gateway: gateway), owner = UUID()
        gateway.permission = false
        service.openReminder(user: owner.uuidString, kind: "learning-reminder")
        var settings = ReminderSettings(); settings.learning = true
        service.update(owner: owner, settings: settings); await service.waitForUpdates()
        XCTAssertTrue(gateway.requests.isEmpty); XCTAssertNotNil(service.programRequest)
        service.programRequest = nil
        service.openReminder(user: UUID().uuidString, kind: "revision-reminder"); XCTAssertNil(service.programRequest)
        service.openReminder(user: owner.uuidString, kind: "unrelated"); XCTAssertNil(service.programRequest)
    }
}
