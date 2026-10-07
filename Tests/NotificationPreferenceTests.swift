import XCTest
@testable import CoranNative

final class NotificationPreferenceTests: XCTestCase {
    func testSingleChangePreservesRemindersAndOtherPreferences() throws {
        let state: JSONValue = .object(["notifications": .object(["learning": .bool(true), "messages": .bool(true), "corrections": .bool(false), "future": .string("kept")])])
        var operation = ReaderOperation(kind: .notifications, verseID: 1, page: 1, source: "native", date: Date(timeIntervalSince1970: 100))
        operation.notification = NotificationPreferenceChange(field: .messages, enabled: false)
        let updated = operation.applying(to: state, catalog: QuranCatalog())
        XCTAssertEqual(updated["notifications"]["learning"], .bool(true))
        XCTAssertEqual(updated["notifications"]["corrections"], .bool(false))
        XCTAssertEqual(updated["notifications"]["future"].string, "kept")
        XCTAssertFalse(NotificationPreferenceChange.Field.messages.value(in: updated))
        XCTAssertEqual(try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(operation)).notification, operation.notification)
        XCTAssertEqual(operation.applying(to: updated, catalog: QuranCatalog()), updated)
    }
    func testServerPatchUsesConfirmedStateAndOnlyChangedColumns() {
        let owner = UUID()
        var old = ReaderOperation(kind: .notifications, verseID: 1, page: 1, source: "native", date: Date(timeIntervalSince1970: 100))
        old.notification = NotificationPreferenceChange(field: .messagePreview, enabled: true)
        var newer = ReaderOperation(kind: .notifications, verseID: 1, page: 1, source: "native", date: Date(timeIntervalSince1970: 200))
        newer.notification = NotificationPreferenceChange(field: .messagePreview, enabled: false)
        let current = newer.applying(to: .object([:]), catalog: QuranCatalog())
        XCTAssertEqual(old.applying(to: current, catalog: QuranCatalog()), current)
        let patch = NotificationPreferenceChange.serverPatch(owner: owner, state: current, operations: [old])!
        XCTAssertEqual(patch["message_preview_enabled"], .bool(false))
        XCTAssertEqual(patch.object.count, 2)
        XCTAssertEqual(patch["user_id"].string, owner.uuidString.lowercased())
        XCTAssertNil(NotificationPreferenceChange.serverPatch(owner: owner, state: current, operations: []))
        XCTAssertFalse(NotificationPreferenceChange.Field.sharedProgress.value(in: .null))
    }
}
