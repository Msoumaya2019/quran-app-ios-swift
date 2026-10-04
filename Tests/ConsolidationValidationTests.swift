import XCTest
@testable import CoranNative

final class ConsolidationValidationTests: XCTestCase {
    func testEarlyValidationPreservesScheduleAndRetryDoesNotAdvanceCycle() throws {
        let state = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"knowledge":{"8":"perfect","9":"unknown"},"memorizedAt":{"8":"2026-10-05","9":"2026-10-05"},"reviewConsolidations":{"8":{"learnedAt":"2026-10-05","scheduledDates":{"1":"2026-10-06","3":"2026-10-08","7":"2026-10-12"},"completed":{}},"9":{"learnedAt":"2026-10-05","completed":{}}},"difficultVerses":{"8":true}}"#.utf8))
        let range = try XCTUnwrap(VerseRange(json: .object(["start": .number(8), "end": .number(9)])))
        let context = QuranSessionContext(id: "test", mode: .consolidation, range: range, scheduledDate: "2026-10-06", consolidationDay: 1, learnedAt: "2026-10-05")
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let validation = try XCTUnwrap(ConsolidationValidation(context: context, now: now, timeZone: TimeZone(identifier: "Europe/Paris")!))
        let next = validation.applying(to: state)
        XCTAssertEqual(next["consolidationHistory"].array.count, 1)
        XCTAssertEqual(next["consolidationHistory"].array.first?["scheduledDate"].string, "2026-10-06")
        XCTAssertEqual(next["reviewConsolidations"]["8"]["completed"]["1"].string, "2026-10-05")
        XCTAssertEqual(next["reviewConsolidations"]["8"]["completed"]["3"], .null)
        XCTAssertEqual(next["reviewConsolidations"]["9"], state["reviewConsolidations"]["9"])
        XCTAssertEqual(next["difficultVerses"], state["difficultVerses"])
        XCTAssertEqual(validation.applying(to: next), next)
        let encoded = try JSONEncoder().encode(validation)
        XCTAssertEqual(try JSONDecoder().decode(ConsolidationValidation.self, from: encoded).applying(to: next), next)
        let relearned = state.setting("memorizedAt", state["memorizedAt"].setting("8", .string("2026-10-07")))
        XCTAssertEqual(validation.applying(to: relearned), relearned)
    }
}
