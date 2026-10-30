import XCTest
@testable import CoranNative

final class StudyCorrectionTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-30T12:00:00Z")!
    private let prior = ISO8601DateFormatter().date(from: "2026-10-20T12:00:00Z")!
    private var state: JSONValue {
        .object(["knowledge": .object(["1": .string("perfect"), "2": .string("perfect"), "3": .string("perfect")]),
                 "reader": .object(["mushaf": .string("tajweed")]), "bookmarks": .object(["2": .bool(true)]),
                 "difficultyMarkers": .object(["2": .object(["user": .bool(true)])]),
                 "sessions": .array([.object(["id": .string("s"), "start": .number(1), "end": .number(3), "date": .string("2026-10-20"), "status": .string("done"), "completedDate": .string("2026-10-20")])])])
    }
    func testWholeDivisionPreservesExistingKnowledgeDatesAndGroupsNewVerses() {
        let input = state.setting("memorizedAt", .object(["1": .string("2026-01-01")]))
            .setting("reviewConsolidations", .object(["1": .object(["learnedAt": .string("2026-01-01"), "completed": .object(["7": .string("2026-01-08")])])]))
        let change = StudyCorrection(action: .learned, start: 1, end: 148, date: now, preserveKnown: true, now: now)
        let result = change.applying(to: input)
        XCTAssertEqual(ProgressProjection(state: result).known.count, 148)
        XCTAssertEqual(result["memorizedAt"]["1"], input["memorizedAt"]["1"])
        XCTAssertEqual(result["reviewConsolidations"]["1"], input["reviewConsolidations"]["1"])
        XCTAssertEqual(result["revisions"].array.count, 1)
        XCTAssertEqual(result["revisions"].array[0]["start"], .number(4))
        XCTAssertEqual(result["revisions"].array[0]["end"], .number(148))
        XCTAssertEqual(change.applying(to: result), result)
    }
    func testOverlappingDivisionsCanBeUncheckedWithoutLosingOtherKnowledge() {
        let filled = StudyCorrection(action: .learned, start: 1, end: 148, date: now, preserveKnown: true, now: now).applying(to: state)
        let result = StudyCorrection(action: .unlearned, start: 1, end: 81, date: now, now: now.addingTimeInterval(1)).applying(to: filled)
        XCTAssertEqual(ProgressProjection(state: result).known, Set(82...148))
        XCTAssertEqual(result["reader"], state["reader"])
    }
    func testUnlearnOneVersePreservesNeighboursScheduledDateAndPrivatePreferences() {
        let change = StudyCorrection(action: .unlearned, start: 2, end: 2, date: now, now: now)
        let result = change.applying(to: state)
        XCTAssertEqual(result["knowledge"]["1"], .string("perfect")); XCTAssertEqual(result["knowledge"]["2"], .null)
        XCTAssertEqual(result["knowledge"]["3"], .string("perfect"))
        for key in ["reader", "bookmarks", "difficultyMarkers"] { XCTAssertEqual(result[key], state[key]) }
        XCTAssertEqual(result["sessions"].array[0]["date"], .string("2026-10-20"))
        XCTAssertEqual(result["sessions"].array[0]["status"], .string("partial"))
        XCTAssertEqual(result["studyProgress"]["learning:s"]["through"], .number(1))
        let validations = result["studyProgress"]["learning:s"]["validations"].array
        XCTAssertEqual(validations.count, 2)
        XCTAssertEqual(change.applying(to: result), result)
    }
    func testLearnedDateUsesExistingKnowledgeAndConsolidationStructures() {
        let change = StudyCorrection(action: .learned, start: 4, end: 5, date: prior, now: now)
        let result = change.applying(to: state)
        for id in ["4", "5"] {
            XCTAssertEqual(result["knowledge"][id], .string("perfect"))
            XCTAssertEqual(result["memorizedAt"][id], .string("2026-10-20"))
            XCTAssertEqual(result["reviewConsolidations"][id]["scheduledDates"]["1"], .string("2026-10-21"))
            XCTAssertEqual(result["reviewConsolidations"][id]["scheduledDates"]["7"], .string("2026-10-27"))
        }
    }
    func testUnknownVerseCannotBeCreditedAsRevisedAndInvalidRangesAreRejected() {
        XCTAssertEqual(StudyCorrection(action: .revised, start: 4, end: 4, date: now, now: now).applying(to: state), state)
        XCTAssertEqual(StudyCorrection(action: .learned, start: 0, end: 4, date: now, now: now).applying(to: state), state)
        XCTAssertEqual(StudyCorrection(action: .learned, start: 1, end: 6237, date: now, now: now).applying(to: state), state)
        XCTAssertEqual(StudyCorrection(action: .learned, start: 1, end: 1, date: now.addingTimeInterval(172800), now: now).applying(to: state), state)
    }
    func testRevisionCanBeAddedEditedAndRemovedWithoutDuplicatingCredits() {
        let added = StudyCorrection(action: .revised, start: 1, end: 2, date: now, now: now).applying(to: state)
        let original = added["reviewHistory"].array[0]
        XCTAssertEqual(added["reviewHistory"].array.count, 1)
        XCTAssertEqual(StudyCorrection(action: .revised, start: 2, end: 3, date: now, now: now.addingTimeInterval(1)).applying(to: added), added)
        let edit = StudyCorrection(action: .revised, start: 1, end: 3, date: prior, original: original, now: now.addingTimeInterval(2))
        let edited = edit.applying(to: added)
        XCTAssertEqual(edited["reviewHistory"].array.count, 1)
        XCTAssertEqual(edited["reviewHistory"].array[0]["end"], .number(3))
        XCTAssertEqual(edited["reviewHistory"].array[0]["date"], .string("2026-10-20"))
        XCTAssertEqual(edit.applying(to: edited), edited)
        let removed = StudyCorrection(action: .removeRevision, start: 1, end: 3, date: prior, original: edited["reviewHistory"].array[0], now: now.addingTimeInterval(3)).applying(to: edited)
        XCTAssertTrue(removed["reviewHistory"].array.isEmpty)
        XCTAssertEqual(removed["knowledge"], state["knowledge"])
        XCTAssertEqual(removed["nativeManualReviewDue"]["2"], .string("2026-10-30"))
    }
    func testEditingStaleHistoryRowIsRejected() {
        let original: JSONValue = .object(["id": .string("missing"), "start": .number(1), "end": .number(2), "date": .string("2026-10-20")])
        XCTAssertEqual(StudyCorrection(action: .revised, start: 1, end: 2, date: prior, original: original, now: now).applying(to: state), state)
    }
    func testResetAndNewerCorrectionsWinOverDelayedOfflineEdits() {
        let change = StudyCorrection(action: .unlearned, start: 1, end: 1, date: now, now: now)
        let reset = state.setting("nativeStudyResetAt", .string("2026-10-30T13:00:00.000Z"))
        XCTAssertEqual(change.applying(to: reset), reset)
        let newer = state.setting("nativeStudyCorrectionAt", .object(["1": .string("2026-10-30T13:00:00.000Z")]))
        XCTAssertEqual(change.applying(to: newer), newer)
        let encoded = try! JSONEncoder().encode(change)
        XCTAssertEqual(try! JSONDecoder().decode(StudyCorrection.self, from: encoded).applying(to: state), change.applying(to: state))
    }
    func testRemovingRevisionReopensAffectedCycleCreditsOnly() {
        let original: JSONValue = .object(["id": .string("r"), "start": .number(1), "end": .number(2), "date": .string("2026-10-30"), "scheduledDate": .string("2026-10-29")])
        let input = state.setting("reviewHistory", .array([original])).setting("reviewCycle", .object(["startDate": .string("2026-10-28"), "corpus": .array([.number(1), .number(2), .number(3)]), "completed": .array([.number(1), .number(2), .number(3)])]))
        let result = StudyCorrection(action: .removeRevision, start: 1, end: 2, date: now, original: original, now: now).applying(to: input)
        XCTAssertEqual(result["reviewCycle"]["completed"], .array([.number(3)]))
    }
}
