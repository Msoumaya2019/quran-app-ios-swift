import XCTest
@testable import CoranNative

final class StudyResetTests: XCTestCase {
    func testResetPreservesPreferencesAndArchivesStudyIdempotently() {
        let state: JSONValue = .object([
            "reader": .object(["mushaf": .string("tajweed")]),
            "bookmarks": .object(["1": .string("kept")]),
            "difficultyMarkers": .object(["2": .string("kept")]),
            "profile": .object(["name": .string("kept")]),
            "knowledge": .object(["1": .string("perfect")]),
            "sessions": .array([.object(["id": .string("old")])]),
            "goal": .object(["title": .string("old")])])
        let id = UUID(), at = "2026-10-30T12:00:00.000Z"
        let reset = StudyReset.applying(to: state, id: id, at: at)
        for key in ["reader", "bookmarks", "difficultyMarkers", "profile"] { XCTAssertEqual(reset[key], state[key]) }
        XCTAssertEqual(reset["knowledge"], .object([:]))
        XCTAssertEqual(reset["sessions"], .array([]))
        XCTAssertEqual(reset["goal"], .null)
        XCTAssertEqual(reset["nativeStudyResetHistory"].array.first?["study"]["knowledge"], state["knowledge"])
        XCTAssertEqual(StudyReset.applying(to: reset, id: id, at: at), reset)
        XCTAssertEqual(StudyReset.applying(to: reset, id: UUID(), at: "2026-10-29T12:00:00.000Z"), reset)
    }
    func testOldOfflineStudyOperationsCannotResurrectProgressAfterReset() {
        let state: JSONValue = .object(["nativeStudyResetAt": .string("2026-10-30T12:00:00.000Z")])
        for kind in [ReaderOperation.Kind.learning, .revision, .consolidation, .program, .reviewSchedule, .verseStudy] {
            let operation = ReaderOperation(kind: kind, verseID: 1, page: 1, source: "", date: Date(timeIntervalSince1970: 0))
            XCTAssertEqual(operation.applying(to: state, catalog: QuranCatalog()), state)
        }
    }
}
