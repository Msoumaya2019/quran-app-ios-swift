import XCTest
@testable import CoranNative

final class MultiSurahProgramTests: XCTestCase {
    let catalog = QuranCatalog()
    func testPageAndRubuIncludeAllSmallSurahsInBothLearningDirections() throws {
        let start = try XCTUnwrap(catalog.pageStarts.first { $0.0 == 604 }?.1)
        let quarter = try XCTUnwrap(catalog.quarters.last)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z"))
        for direction in ["fromStart", "fromNas"] {
            for (pace, first) in [("page", start), ("quarter", quarter.start)] {
                let goal: JSONValue = .object(["direction": .string(direction), "ranges": .array([.object(["start": .number(Double(first)), "end": .number(6236)])])])
                let edit = ProgramEdit(goal: goal, pace: pace, days: Array(0...6), now: now, timeZone: TimeZone(identifier: "Europe/Paris")!)
                let rows = try XCTUnwrap(edit.generatedSessions(state: .object([:]), catalog: catalog, preview: true))
                XCTAssertEqual(rows.count, 1)
                XCTAssertEqual(rows[0]["start"].int, first); XCTAssertEqual(rows[0]["end"].int, 6236)
                XCTAssertNotEqual(catalog.surah(for: first)?.number, catalog.surah(for: 6236)?.number)
            }
        }
    }
    func testExistingSplitLearningSessionsValidateTogetherWithoutChangingDatesOrIDs() throws {
        let surahs = Array(catalog.surahs.suffix(3)), day = "2026-10-07"
        let rows: [JSONValue] = surahs.map { .object(["id": .string("legacy-\($0.number)"), "start": .number(Double($0.start)), "end": .number(Double($0.end)), "unit": .string("page"), "status": .string("todo"), "scheduledDate": .string(day), "date": .string(day)]) }
        let state: JSONValue = .object(["sessions": .array(rows)])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: day + "T12:00:00Z"))
        let context = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: state), now: now).todayLearning)
        XCTAssertEqual(context.range.start, surahs[0].start); XCTAssertEqual(context.range.end, 6236)
        XCTAssertEqual(context.learningSessionIDs?.count, 3)
        let partial = try XCTUnwrap(LearningValidation(context: context, through: surahs[0].end, source: "traditional", catalog: catalog, now: now)).applying(to: state)
        XCTAssertEqual(LearningValidation.completedCount(context: context, state: partial), surahs[0].end - surahs[0].start + 1)
        let complete = try XCTUnwrap(LearningValidation(context: context, through: 6236, source: "traditional", catalog: catalog, now: now)).applying(to: partial)
        XCTAssertEqual(complete["sessions"].array.map { $0["id"] }, rows.map { $0["id"] })
        XCTAssertTrue(complete["sessions"].array.allSatisfy { $0["status"].string == "done" && $0["scheduledDate"].string == day })
        XCTAssertEqual(LearningValidation.completedCount(context: context, state: complete), context.range.count)
        let validation = try XCTUnwrap(LearningValidation(context: context, through: 6236, source: "traditional", catalog: catalog, now: now))
        XCTAssertEqual(validation.applying(to: complete), complete)
    }
    func testRevisionKeepsContiguousDailyUnitAcrossSurahBoundariesButStopsAtUnknownGap() throws {
        let start = try XCTUnwrap(catalog.pageStarts.first { $0.0 == 604 }?.1), day = "2026-10-07"
        let ids = Array(start...6236)
        let cycle: JSONValue = .object(["index": .number(1), "startDate": .string(day), "corpus": .array(ids.map { .number(Double($0)) }), "days": .array([.array(ids.map { .number(Double($0)) })]), "assignments": .object([day: .number(0)]), "completed": .array([])])
        let knowledge: JSONValue = .object(Dictionary(uniqueKeysWithValues: ids.map { (String($0), JSONValue.string("perfect")) }))
        let state: JSONValue = .object(["reviewCycle": cycle, "knowledge": knowledge])
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: day + "T12:00:00Z"))
        let whole = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: state), now: now).habitualRevision)
        XCTAssertEqual(whole.range.start, start); XCTAssertEqual(whole.range.end, 6236)
        let gap = start + 4
        let partialState = state.setting("knowledge", knowledge.setting(String(gap), .string("unknown")))
        let fragment = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: partialState), now: now).habitualRevision)
        XCTAssertEqual(fragment.range.end, gap - 1)
    }
}
