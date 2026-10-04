import XCTest
@testable import CoranNative

final class ReviewQueueTests: XCTestCase {
    private let zone = TimeZone(identifier: "Europe/Paris")!
    private var now: Date { ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z")! }
    private func state() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(#"{"reviewSettings":{"enabled":true,"cycleDays":7},"knowledge":{"1":"perfect","2":"perfect","3":"perfect","4":"perfect","5":"learning"},"memorizedAt":{"2":"2026-10-04","3":"2026-10-04"},"reviewConsolidations":{"2":{"learnedAt":"2026-10-04","completed":{}},"3":{"learnedAt":"2026-10-04","completed":{}}},"difficultyMarkers":{"1":{"user":{"createdAt":"2026-10-01"},"admin":{"note":"keep"}},"2":{"user":{"createdAt":"2026-10-01"}},"4":{"user":{"createdAt":"2026-10-01"}},"5":{"user":{"createdAt":"2026-10-01"}}},"reviewPriorityDue":{"1":"2026-10-03","2":"2026-10-03","4":"2026-10-06"},"reviewCycle":{"index":1,"startDate":"2026-10-05","days":[[1,2,3,4]],"corpus":[1,2,3,4],"assignments":{"2026-10-05":0},"completed":[]},"other":{"keep":true}}"#.utf8))
    }
    private func queue(_ state: JSONValue, date: Date? = nil) -> [QuranSessionContext] {
        ReviewQueueProjection(program: ProgramProjection(snapshot: HomeSnapshot(state: state), now: date ?? now, timeZone: zone)).tasks
    }
    private func operation(_ state: JSONValue, task: QuranSessionContext, through: Int? = nil, grade: RevisionGrade = .perfect, date: Date? = nil) throws -> ReaderOperation {
        let at = date ?? now
        let value = try XCTUnwrap(RevisionValidation(context: task, through: through ?? task.range.end, grade: grade, state: state, source: .medina, catalog: QuranCatalog(), now: at, timeZone: zone))
        var operation = ReaderOperation(kind: .revision, verseID: task.range.start, page: 1, source: "traditional", date: at); operation.revision = value; return operation
    }
    func testQueueOrdersRecentPriorityHabitualWithoutDuplicateOrUnknownVerses() throws {
        let tasks = queue(try state())
        XCTAssertEqual(tasks.map { $0.revisionCategory ?? "habitual" }, ["recent", "priority", "habitual"])
        XCTAssertEqual(tasks.map { Array($0.range.start...$0.range.end) }, [[2,3],[1],[4]])
        XCTAssertEqual(tasks[1].scheduledDate, "2026-10-03")
        XCTAssertEqual(tasks[0].consolidationDay, 1)
        XCTAssertEqual(Set(tasks.flatMap { Array($0.range.start...$0.range.end) }).count, 4)
    }
    func testPriorityValidationCreditsOverlapRetainsDifficultyAndPlansNextDue() throws {
        let original = try state(), task = try XCTUnwrap(queue(original).first { $0.revisionCategory == "priority" })
        let op = try operation(original, task: task), next = op.applying(to: original, catalog: QuranCatalog())
        XCTAssertEqual(next["reviewHistory"].array.first?["category"].string, "priority")
        XCTAssertEqual(next["reviewHistory"].array.first?["scheduledDate"].string, "2026-10-03")
        XCTAssertEqual(next["reviewPriorityDue"]["1"].string, "2026-10-12")
        XCTAssertEqual(next["difficultyMarkers"], original["difficultyMarkers"])
        XCTAssertEqual(next["reviewCycle"]["completed"].array.compactMap(\.int), [1])
        XCTAssertEqual(next["other"], original["other"])
        XCTAssertEqual(op.applying(to: next, catalog: QuranCatalog()), next)
    }
    func testRecentPartialResumeAndCompletionAdvancesOnlyCurrentConsolidation() throws {
        let original = try state(), task = try XCTUnwrap(queue(original).first)
        let partial = try operation(original, task: task, through: 2).applying(to: original, catalog: QuranCatalog())
        let resumed = try XCTUnwrap(queue(partial).first)
        XCTAssertEqual(resumed.id, task.id); XCTAssertEqual(resumed.range, task.range)
        XCTAssertEqual(RevisionValidation.completedCount(context: resumed, state: partial), 1)
        let op = try operation(partial, task: resumed), next = op.applying(to: partial, catalog: QuranCatalog())
        XCTAssertEqual(next["reviewConsolidations"]["2"]["completed"]["1"].string, "2026-10-05")
        XCTAssertEqual(next["reviewConsolidations"]["3"]["completed"]["1"].string, "2026-10-05")
        XCTAssertEqual(next["reviewConsolidations"]["3"]["completed"]["3"], .null)
        XCTAssertEqual(next["consolidationHistory"].array.count, 2)
        XCTAssertEqual(next["reviewCycle"]["completed"].array.compactMap(\.int), [2,3])
        XCTAssertEqual(op.applying(to: next, catalog: QuranCatalog()), next)
    }
    func testPriorityNeedsNoHabitualCycleAndGradesScheduleWithoutRemovingAdmin() throws {
        let original = try state().setting("reviewCycle", .null)
        let task = try XCTUnwrap(queue(original).first { $0.revisionCategory == "priority" })
        for grade in [RevisionGrade.hesitant, .rework] {
            let next = try operation(original, task: task, grade: grade).applying(to: original, catalog: QuranCatalog())
            XCTAssertEqual(next["reviewCycle"], .null)
            XCTAssertEqual(next["reviewPriorityDue"]["1"].string, grade == .rework ? "2026-10-06" : "2026-10-07")
            XCTAssertEqual(next["difficultyMarkers"]["1"]["admin"], original["difficultyMarkers"]["1"]["admin"])
        }
    }
    func testRemovedDifficultyRescheduledDueAndRelearningRejectStaleValidation() throws {
        let original = try state(), task = try XCTUnwrap(queue(original).first { $0.revisionCategory == "priority" })
        let op = try operation(original, task: task)
        let removed = original.setting("difficultyMarkers", original["difficultyMarkers"].setting("1", .null))
        XCTAssertEqual(op.applying(to: removed, catalog: QuranCatalog()), removed)
        let changed = original.setting("reviewPriorityDue", original["reviewPriorityDue"].setting("1", .string("2026-10-12")))
        XCTAssertEqual(op.applying(to: changed, catalog: QuranCatalog()), changed)
        let relearned = original.setting("memorizedAt", original["memorizedAt"].setting("1", .string("2026-10-05")))
        XCTAssertEqual(op.applying(to: relearned, catalog: QuranCatalog()), relearned)
    }
    func testPausedFutureAndAlreadyReviewedContentDoesNotReturnToday() throws {
        let original = try state()
        XCTAssertTrue(queue(original.setting("reviewSettings", .object(["enabled": .bool(false)]))).isEmpty)
        let future = ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z")!
        XCTAssertFalse(queue(original, date: future).contains { $0.revisionCategory == "recent" })
        let done = original.setting("reviewHistory", .array([.object(["date": .string("2026-10-05"), "start": .number(1), "end": .number(4)])]))
        XCTAssertTrue(queue(done).isEmpty)
    }
    func testEarlyRecentValidationPreservesScheduledDateAndSerializedOperationReplays() throws {
        let original = try state(), task = try XCTUnwrap(queue(original).first)
        let early = ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z")!
        let op = try operation(original, task: task, date: early)
        let restored = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(op))
        let next = restored.applying(to: original, catalog: QuranCatalog())
        XCTAssertEqual(next["reviewHistory"].array.first?["scheduledDate"].string, "2026-10-05")
        XCTAssertEqual(next["reviewHistory"].array.first?["date"].string, "2026-10-04")
        XCTAssertEqual(next["consolidationHistory"].array.first?["scheduledDate"].string, "2026-10-05")
        XCTAssertEqual(next["reviewConsolidations"]["2"]["completed"]["1"].string, "2026-10-04")
        XCTAssertEqual(restored.applying(to: next, catalog: QuranCatalog()), next)
    }
}
