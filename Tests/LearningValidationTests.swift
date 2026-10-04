import XCTest
@testable import CoranNative

final class LearningValidationTests: XCTestCase {
    private func state() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(#"{"sessions":[{"id":"monday","date":"2026-10-05","scheduledDate":"2026-10-05","start":1,"end":7,"status":"todo"},{"id":"tuesday","date":"2026-10-06","scheduledDate":"2026-10-06","start":8,"end":10,"status":"todo"}],"knowledge":{},"memorizedAt":{},"difficultyMarkers":{"1":{"user":{"createdAt":"2026-10-01"}}},"unknownFutureField":{"keep":true}}"#.utf8))
    }
    private func operation(_ id: String = "monday", start: Int = 1, end: Int = 7, through: Int = 7, day: String = "2026-10-05", actual: String = "2026-10-05T12:00:00Z") throws -> ReaderOperation {
        let range = try XCTUnwrap(VerseRange(json: .object(["start": .number(Double(start)), "end": .number(Double(end))])))
        let context = QuranSessionContext(id: id, mode: .learning, range: range, scheduledDate: day)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: actual))
        let validation = try XCTUnwrap(LearningValidation(context: context, through: through, source: "traditional", catalog: QuranCatalog(), now: now, timeZone: TimeZone(identifier: "Europe/Paris")!))
        var operation = ReaderOperation(kind: .learning, verseID: through, page: validation.page, source: "traditional", date: now)
        operation.learning = validation
        return operation
    }
    func testOnTimeEarlyAndLateNeverMoveScheduledDates() throws {
        for actual in ["2026-10-04T12:00:00Z", "2026-10-05T12:00:00Z", "2026-10-07T12:00:00Z"] {
            let original = try state(), op = try operation(actual: actual)
            let next = op.applying(to: original, catalog: QuranCatalog())
            XCTAssertEqual(next["sessions"].array[0]["scheduledDate"].string, "2026-10-05")
            XCTAssertEqual(next["sessions"].array[0]["date"].string, "2026-10-05")
            XCTAssertEqual(next["sessions"].array[0]["completedDate"].string, String(actual.prefix(10)))
            XCTAssertEqual(next["sessions"].array[0]["status"].string, "done")
            XCTAssertEqual(next["sessions"].array[1], original["sessions"].array[1])
            XCTAssertEqual(next["difficultyMarkers"], original["difficultyMarkers"])
            XCTAssertEqual(next["unknownFutureField"], original["unknownFutureField"])
            XCTAssertEqual(op.applying(to: next, catalog: QuranCatalog()), next)
        }
        let tuesday = try operation("tuesday", start: 8, end: 10, through: 10, day: "2026-10-06")
        XCTAssertEqual(tuesday.applying(to: try state(), catalog: QuranCatalog())["sessions"].array[1]["scheduledDate"].string, "2026-10-06")
    }
    func testPartialResumeAndQueueReplayCreditOnlyNewVerses() throws {
        let catalog = QuranCatalog(), first = try operation(through: 3)
        let partial = first.applying(to: try state(), catalog: catalog)
        XCTAssertEqual(partial["sessions"].array[0]["status"].string, "todo")
        XCTAssertEqual(partial["studyProgress"]["learning:monday"]["status"].string, "partial")
        XCTAssertEqual(partial["knowledge"].object.count, 3)
        let last = try operation(actual: "2026-10-06T12:00:00Z")
        let restored = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(last))
        let completed = restored.applying(to: partial, catalog: catalog)
        XCTAssertEqual(completed["knowledge"].object.count, 7)
        XCTAssertEqual(completed["studyProgress"]["learning:monday"]["validations"].array.map { $0["start"].int }, [1, 4])
        XCTAssertEqual(completed["memorizedAt"]["1"].string, "2026-10-05")
        XCTAssertEqual(completed["memorizedAt"]["4"].string, "2026-10-06")
        XCTAssertEqual(completed["reviewConsolidations"]["1"]["scheduledDates"]["7"].string, "2026-10-12")
        XCTAssertEqual(completed["reviewConsolidations"]["4"]["scheduledDates"]["7"].string, "2026-10-13")
        XCTAssertEqual(first.applying(to: completed, catalog: catalog), completed)
        XCTAssertEqual(restored.applying(to: completed, catalog: catalog), completed)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-06T12:00:00Z"))
        let home = HomeProjection(snapshot: HomeSnapshot(state: completed), now: now, timeZone: TimeZone(identifier: "Europe/Paris")!)
        XCTAssertEqual(home.weeklyVerseCounts, [3, 4, 0, 0, 0, 0, 0])
        XCTAssertEqual(home.week.done, 1)
        XCTAssertEqual(home.week.total, 2)
    }
    func testConcurrentPrefixNeverCreditsSameVersesTwice() throws {
        let newer = try operation(through: 5), older = try operation(through: 3)
        let shared = newer.applying(to: try state(), catalog: QuranCatalog())
        XCTAssertEqual(older.applying(to: shared, catalog: QuranCatalog()), shared)
        let final = try operation().applying(to: shared, catalog: QuranCatalog())
        XCTAssertEqual(final["studyProgress"]["learning:monday"]["validations"].array.map { $0["start"].int }, [1, 6])
        XCTAssertEqual(final["revisions"].array.count, 2)
    }
    func testChangedOrMissingSessionCannotReceiveOldValidation() throws {
        let original = try state(), op = try operation()
        XCTAssertEqual(op.applying(to: original.setting("sessions", .array([])), catalog: QuranCatalog()), original.setting("sessions", .array([])))
        var sessions = original["sessions"].array
        sessions[0] = sessions[0].setting("scheduledDate", .string("2026-10-08"))
        let moved = original.setting("sessions", .array(sessions))
        XCTAssertEqual(op.applying(to: moved, catalog: QuranCatalog()), moved)
    }
}
