import XCTest
@testable import CoranNative

final class RevisionValidationTests: XCTestCase {
    private func state() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(#"{"reviewSettings":{"enabled":true,"cycleDays":7},"reviewCycle":{"index":1,"startDate":"2026-10-05","lengthDays":7,"corpus":[1,2,3],"days":[[1,2,3]],"completed":[],"assignments":{"2026-10-05":0}},"knowledge":{"1":"perfect","2":"review","3":"perfect"},"difficultyMarkers":{"1":{"user":{"createdAt":"2026-10-01"},"admin":{"createdAt":"2026-10-01","comment":"Keep"}}},"other":{"keep":true}}"#.utf8))
    }
    private func operation(_ state: JSONValue, through: Int = 3, grade: RevisionGrade = .perfect, actual: String = "2026-10-05T12:00:00Z") throws -> ReaderOperation {
        let range = try XCTUnwrap(VerseRange(json: .object(["start": .number(1), "end": .number(3)])))
        let context = QuranSessionContext(id: "native-revision-1-2026-10-05-1-3", mode: .revision, range: range, scheduledDate: "2026-10-05", revisionCycleIndex: 1, revisionCycleStart: "2026-10-05")
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: actual))
        let validation = try XCTUnwrap(RevisionValidation(context: context, through: through, grade: grade, state: state, source: .medina, catalog: QuranCatalog(), now: now, timeZone: TimeZone(identifier: "Europe/Paris")!))
        var op = ReaderOperation(kind: .revision, verseID: through, page: validation.page, source: "traditional", date: now); op.revision = validation; return op
    }
    func testEarlyAndLateKeepPlannedDateAndDifficulty() throws {
        for actual in ["2026-10-04T12:00:00Z", "2026-10-07T12:00:00Z"] {
            let original = try state(), op = try operation(original, actual: actual)
            let next = op.applying(to: original, catalog: QuranCatalog())
            XCTAssertEqual(next["reviewHistory"].array.count, 1)
            XCTAssertEqual(next["reviewHistory"].array[0]["scheduledDate"].string, "2026-10-05")
            XCTAssertEqual(next["reviewHistory"].array[0]["date"].string, String(actual.prefix(10)))
            XCTAssertEqual(next["reviewCycle"]["startDate"], original["reviewCycle"]["startDate"])
            XCTAssertEqual(next["difficultyMarkers"], original["difficultyMarkers"])
            XCTAssertEqual(next["other"], original["other"])
            XCTAssertEqual(op.applying(to: next, catalog: QuranCatalog()), next)
        }
    }
    func testGradesMarkDifficultyWithoutRemovingAdminAndSetDue() throws {
        for grade in [RevisionGrade.hesitant, .rework] {
            let original = try state(), next = try operation(original, grade: grade).applying(to: original, catalog: QuranCatalog())
            XCTAssertEqual(next["difficultyMarkers"]["1"]["admin"], original["difficultyMarkers"]["1"]["admin"])
            XCTAssertEqual(next["difficultyMarkers"]["2"]["user"]["createdAt"].string, "2026-10-05")
            XCTAssertEqual(next["difficultyHistory"].array.count, 2)
            XCTAssertEqual(next["reviewPriorityDue"]["2"].string, grade == .rework ? "2026-10-06" : "2026-10-07")
        }
    }
    func testPartialSerializationAndConcurrentReviewDoNotDuplicateHistory() throws {
        let original = try state(), first = try operation(original, through: 1)
        let partial = first.applying(to: original, catalog: QuranCatalog())
        let last = try operation(original)
        let restored = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(last))
        let next = restored.applying(to: partial, catalog: QuranCatalog())
        XCTAssertEqual(next["reviewHistory"].array.map { $0["start"].int }, [1, 2])
        XCTAssertEqual(next["reviewCycle"]["completed"].array.compactMap(\.int), [1, 2, 3])
        XCTAssertEqual(restored.applying(to: next, catalog: QuranCatalog()), next)
        let duplicate = try operation(original).applying(to: next, catalog: QuranCatalog())
        XCTAssertEqual(duplicate, next)
    }
    func testOldCycleUnknownVersesAndRelearningRejectStaleOperations() throws {
        let original = try state(), op = try operation(original)
        let newCycle = original.setting("reviewCycle", original["reviewCycle"].setting("index", .number(2)))
        XCTAssertEqual(op.applying(to: newCycle, catalog: QuranCatalog()), newCycle)
        let unknown = original.setting("knowledge", original["knowledge"].setting("2", .string("learning")))
        XCTAssertEqual(op.applying(to: unknown, catalog: QuranCatalog()), unknown)
        let relearned = original.setting("memorizedAt", .object(["2": .string("2026-10-06")]))
        XCTAssertEqual(op.applying(to: relearned, catalog: QuranCatalog()), relearned)
    }
    func testProjectionUsesRealScheduledDayAndCycleScopedTask() throws {
        let original = try state()
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let task = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: original), now: now).revision)
        XCTAssertEqual(task.scheduledDate, "2026-10-05")
        XCTAssertEqual(task.id, "native-revision-1-2026-10-05-1-3")
        let partial = try operation(original, through: 1).applying(to: original, catalog: QuranCatalog())
        let resumed = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: partial), now: now).revision)
        XCTAssertEqual(resumed.id, task.id)
        XCTAssertEqual(resumed.range.start, 1)
        XCTAssertEqual(RevisionValidation.completedCount(context: resumed, state: partial), 1)
    }
}
