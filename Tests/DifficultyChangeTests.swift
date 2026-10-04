import XCTest
@testable import CoranNative

final class DifficultyChangeTests: XCTestCase {
    func testMarkSurvivesDiskAndQueueReplayThenVoluntaryRemoval() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = LocalStorageService(directory: directory), user = UUID(), catalog = QuranCatalog()
        var operation = ReaderOperation(kind: .difficulty, verseID: 1, page: 1, source: "traditional")
        operation.difficulty = DifficultyChange(verseID: 1, difficult: true)
        var snapshot = HomeSnapshot(state: .object(["keep": .bool(true)]))
        snapshot.state = operation.applying(to: snapshot.state, catalog: catalog); snapshot.readerOperations = [operation]
        try cache.save(snapshot, userID: user)
        let restored = try XCTUnwrap(try cache.load(userID: user))
        XCTAssertTrue(DifficultyChange.isDifficult(restored.state, verseID: 1))
        XCTAssertEqual(restored.readerOperations?.first?.applying(to: restored.state, catalog: catalog), restored.state)
        let removed = DifficultyChange(verseID: 1, difficult: false).applying(to: restored.state)
        XCTAssertFalse(DifficultyChange.isDifficult(removed, verseID: 1))
        XCTAssertEqual(removed["keep"], .bool(true))
        XCTAssertEqual(removed["difficultyHistory"].array.count, 2)
    }
    func testRemovingUserDifficultyPreservesAdminAndUnknownFields() throws {
        let state = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"difficultyMarkers":{"1":{"user":{"createdAt":"2026-10-01"},"admin":{"comment":"keep"},"futureField":true}},"reviewPriorityDue":{"1":"2026-10-04"}}"#.utf8))
        let next = DifficultyChange(verseID: 1, difficult: false).applying(to: state)
        XCTAssertEqual(next["difficultyMarkers"]["1"]["user"], .null)
        XCTAssertEqual(next["difficultyMarkers"]["1"]["admin"], state["difficultyMarkers"]["1"]["admin"])
        XCTAssertEqual(next["difficultyMarkers"]["1"]["futureField"], .bool(true))
        XCTAssertTrue(DifficultyChange.isDifficult(next, verseID: 1))
        XCTAssertEqual(next["reviewPriorityDue"], state["reviewPriorityDue"])
    }
    func testOlderOfflineMarkCannotUndoLaterNativeRemovalAndDayUsesParis() throws {
        let old = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-04T22:30:00Z"))
        let mark = DifficultyChange(verseID: 1, difficult: true, now: old, timeZone: TimeZone(identifier: "Europe/Paris")!)
        let remove = DifficultyChange(verseID: 1, difficult: false, now: old.addingTimeInterval(60))
        let state = remove.applying(to: mark.applying(to: .object([:])))
        XCTAssertEqual(mark.day, "2026-10-05")
        XCTAssertEqual(mark.applying(to: state), state)
        XCTAssertEqual(DifficultyChange(verseID: 0, difficult: true).applying(to: state), state)
    }
}
