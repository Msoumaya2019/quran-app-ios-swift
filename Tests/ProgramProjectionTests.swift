import XCTest
@testable import CoranNative

final class ProgramProjectionTests: XCTestCase {
    private let paris = TimeZone(identifier: "Europe/Paris")!
    func testUpcomingUsesScheduledDateAndStopsAtDayTen() throws {
        let data = Data(#"{"sessions":[{"id":"early","start":1,"end":7,"status":"todo","scheduledDate":"2026-10-06","completedAt":"2026-10-05T08:00:00Z","date":"2026-10-05"},{"id":"late","start":8,"end":10,"status":"todo","scheduledDate":"2026-10-04"},{"id":"ten","start":11,"end":12,"status":"todo","scheduledDate":"2026-10-15"},{"id":"eleven","start":13,"end":14,"status":"todo","scheduledDate":"2026-10-16"}]}"#.utf8)
        let state = try JSONDecoder().decode(JSONValue.self, from: data)
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let projection = ProgramProjection(snapshot: HomeSnapshot(state: state), now: now, timeZone: paris)
        XCTAssertEqual(projection.upcoming.map(\.id), ["early", "ten"])
        XCTAssertEqual(projection.upcoming.first?.scheduledDate, "2026-10-06")
        XCTAssertEqual(projection.overdue.first?.scheduledDate, "2026-10-04")
        XCTAssertEqual(projection.dateLabel("2026-10-06"), "Demain")
        XCTAssertEqual(projection.snapshot.state, state)
    }
    func testConsolidationKeepsTheoreticalDatesAndSkipsUnknownVerses() throws {
        let state = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"knowledge":{"8":"perfect","9":"review","10":"unknown"},"memorizedAt":{"8":"2026-10-05","9":"2026-10-05","10":"2026-10-05"},"reviewConsolidations":{"8":{"learnedAt":"2026-10-05","completed":{"1":"2026-10-05"}},"9":{"learnedAt":"2026-10-05","completed":{"1":"2026-10-05"}},"10":{"learnedAt":"2026-10-05","completed":{}}}}"#.utf8))
        let projection = ProgramProjection(snapshot: HomeSnapshot(state: state), timeZone: paris)
        XCTAssertEqual(projection.consolidations.count, 1)
        XCTAssertEqual(projection.consolidations.first?.range.count, 2)
        XCTAssertEqual(projection.consolidations.first?.consolidationDay, 3)
        XCTAssertEqual(projection.consolidations.first?.scheduledDate, "2026-10-08")
        XCTAssertEqual(ProgramProjection.addingDays(1, to: "2026-10-05", timeZone: paris), "2026-10-06")
        XCTAssertEqual(ProgramProjection.addingDays(7, to: "2026-10-05", timeZone: paris), "2026-10-12")
    }
    func testCalendarDaysAcrossDSTAndInvalidDates() {
        XCTAssertEqual(ProgramProjection.addingDays(1, to: "2026-10-25", timeZone: paris), "2026-10-26")
        XCTAssertEqual(ProgramProjection.addingDays(1, to: "2026-03-29", timeZone: paris), "2026-03-30")
        XCTAssertNil(ProgramProjection.addingDays(1, to: "2026-02-30", timeZone: paris))
    }
}
