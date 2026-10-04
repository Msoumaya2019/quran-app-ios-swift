import XCTest
@testable import CoranNative

final class ConsolidationRecoveryTests: XCTestCase {
    private func state() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(#"{"knowledge":{"1":"perfect","2":"perfect","3":"learning"},"memorizedAt":{"1":"2026-10-05","2":"2026-10-05","3":"2026-10-05"},"reviewHistory":[{"date":"2026-10-06","start":1,"end":3,"completedAt":"2026-10-06T10:00:00Z"},{"date":"2026-10-06","start":1,"end":2},{"date":"2026-10-09","start":1,"end":1},{"date":"2026-10-12","start":1,"end":1}],"other":true}"#.utf8))
    }
    func testOnlyDistinctRealReviewDatesRestoreCheckpointsAndUnknownVersesAreExcluded() throws {
        let original = try state(), next = ConsolidationRecovery.applying(to: original)
        XCTAssertEqual(next["reviewConsolidations"]["1"]["completed"]["1"].string, "2026-10-06")
        XCTAssertEqual(next["reviewConsolidations"]["1"]["completed"]["3"].string, "2026-10-09")
        XCTAssertEqual(next["reviewConsolidations"]["1"]["completed"]["7"].string, "2026-10-12")
        XCTAssertEqual(next["reviewConsolidations"]["2"]["completed"]["1"].string, "2026-10-06")
        XCTAssertEqual(next["reviewConsolidations"]["2"]["completed"]["3"], .null)
        XCTAssertEqual(next["reviewConsolidations"]["3"], .null)
        XCTAssertEqual(next["reviewConsolidations"]["1"]["completedAt"]["1"].string, "2026-10-06T10:00:00Z")
        XCTAssertEqual(next["reviewHistory"], original["reviewHistory"])
        XCTAssertEqual(next["other"], original["other"])
        XCTAssertEqual(ConsolidationRecovery.applying(to: next), next)
    }
    func testStoredCompletionAndScheduledDatesRemainImmutable() throws {
        let row: JSONValue = .object(["learnedAt": .string("2026-10-05"), "scheduledDates": .object(["1": .string("2026-10-07")]), "completed": .object(["1": .string("2026-10-05")]), "futureField": .bool(true)])
        let next = ConsolidationRecovery.applying(to: try state().setting("reviewConsolidations", .object(["1": row])))
        XCTAssertEqual(next["reviewConsolidations"]["1"]["completed"], row["completed"])
        XCTAssertEqual(next["reviewConsolidations"]["1"]["scheduledDates"]["1"].string, "2026-10-07")
        XCTAssertEqual(next["reviewConsolidations"]["1"]["scheduledDates"]["3"].string, "2026-10-08")
        XCTAssertEqual(next["reviewConsolidations"]["1"]["futureField"].bool, true)
    }
    func testMissingReviewsAndRelearningNeverInventCompletions() throws {
        let original = try state().setting("reviewHistory", .array([]))
        let next = ConsolidationRecovery.applying(to: original)
        XCTAssertTrue(next["reviewConsolidations"]["1"]["completed"].object.isEmpty)
        let relearned = next.setting("memorizedAt", next["memorizedAt"].setting("1", .string("2026-10-20")))
        let result = ConsolidationRecovery.applying(to: relearned)
        XCTAssertEqual(result["reviewConsolidations"]["1"]["scheduledDates"]["7"].string, "2026-10-27")
        XCTAssertTrue(result["reviewConsolidations"]["1"]["completed"].object.isEmpty)
    }
}
