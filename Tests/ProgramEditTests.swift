import XCTest
@testable import CoranNative

final class ProgramEditTests: XCTestCase {
    private let catalog = QuranCatalog()
    private func goal(_ start: Int = 1, _ end: Int = 7, direction: String = "fromStart") -> JSONValue {
        .object(["label": .string("Objectif test"), "direction": .string(direction), "ranges": .array([.object(["start": .number(Double(start)), "end": .number(Double(end))])])])
    }
    private func edit(_ goal: JSONValue, pace: String = "verse2", days: [Int] = Array(0...6), now: String = "2026-10-05T12:00:00Z") throws -> ProgramEdit {
        ProgramEdit(goal: goal, pace: pace, days: days, now: try XCTUnwrap(ISO8601DateFormatter().date(from: now)), timeZone: TimeZone(identifier: "Europe/Paris")!)
    }
    func testEditPreservesCompletedPartialKnowledgeAndOriginalDates() throws {
        let state = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"knowledge":{"1":"perfect","2":"perfect","3":"perfect"},"sessions":[{"id":"done","date":"2026-10-01","scheduledDate":"2026-10-01","start":1,"end":2,"status":"done","completedAt":"2026-10-01T12:00:00Z"},{"id":"partial","date":"2026-10-04","scheduledDate":"2026-10-04","start":3,"end":4,"status":"todo"},{"id":"future","date":"2026-10-06","scheduledDate":"2026-10-06","start":5,"end":7,"status":"todo"}],"studyProgress":{"learning:partial":{"status":"partial","through":3}},"difficultyMarkers":{"3":{"admin":{"comment":"keep"}}},"consolidationHistory":[{"id":"keep"}],"futureField":{"keep":true}}"#.utf8))
        let change = try edit(goal()), next = change.applying(to: state, catalog: catalog)
        let rows = next["sessions"].array
        XCTAssertEqual(rows.first { $0["id"].string == "done" }, state["sessions"].array[0])
        XCTAssertEqual(rows.first { $0["id"].string == "partial" }, state["sessions"].array[1])
        XCTAssertEqual(rows.first { $0["id"].string == "future" }?["status"].string, "postponed")
        let generated = rows.filter { ($0["id"].string ?? "").contains(change.id) }
        XCTAssertEqual(generated.map { $0["start"].int }, [5, 7])
        XCTAssertEqual(generated.map { $0["scheduledDate"].string }, ["2026-10-05", "2026-10-06"])
        for key in ["knowledge", "studyProgress", "difficultyMarkers", "consolidationHistory", "futureField"] { XCTAssertEqual(next[key], state[key]) }
    }
    func testOfflineReplayDoesNotRegenerateAndOlderEditCannotReplaceNewer() throws {
        let first = try edit(goal()), newer = try edit(goal(), pace: "page", now: "2026-10-05T12:01:00Z")
        let state: JSONValue = .object([:])
        var operation = ReaderOperation(kind: .program, verseID: 1, page: 1, source: "traditional"); operation.program = first
        let restored = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(operation))
        let saved = restored.applying(to: state, catalog: catalog)
        XCTAssertEqual(restored.applying(to: saved, catalog: catalog), saved)
        let changed = newer.applying(to: saved, catalog: catalog)
        XCTAssertEqual(changed["pace"].string, "page")
        XCTAssertEqual(first.applying(to: changed, catalog: catalog), changed)
        XCTAssertEqual(changed["nativeProgramEdits"].array.count, 2)
    }
    func testDaysUseParisCalendarAcrossBothDSTTransitions() throws {
        for (now, expected) in [("2026-10-24T12:00:00Z", ["2026-10-25", "2026-11-01"]), ("2026-03-28T12:00:00Z", ["2026-03-29", "2026-04-05"])] {
            let rows = try XCTUnwrap(try edit(goal(1, 2), pace: "verse1", days: [0], now: now).generatedSessions(state: .object([:]), catalog: catalog))
            XCTAssertEqual(rows.map { $0["scheduledDate"].string }, expected)
        }
    }
    func testQuranDivisionPacesUseOriginalBoundariesAndHalfPageWeights() throws {
        XCTAssertEqual(ProgramEdit.weights.count, 6236)
        for (pace, end) in [("quarter", catalog.quarters[0].end), ("halfHizb", catalog.quarters[1].end), ("hizb", catalog.hizbs[0].end)] {
            let rows = try XCTUnwrap(try edit(goal(1, 6236), pace: pace).generatedSessions(state: .object([:]), catalog: catalog, preview: true))
            XCTAssertEqual(rows.first?["start"].int, 1)
            XCTAssertEqual(rows.last?["end"].int, end)
        }
        let rows = try XCTUnwrap(try edit(goal(), pace: "halfPage").generatedSessions(state: .object([:]), catalog: catalog, preview: true))
        let through = try XCTUnwrap(rows.first?["end"].int)
        let total = ProgramEdit.weights.prefix(7).reduce(0, +)
        XCTAssertGreaterThanOrEqual(Double(ProgramEdit.weights.prefix(through).reduce(0, +)), Double(total) / 2)
        if through > 1 { XCTAssertLessThan(Double(ProgramEdit.weights.prefix(through - 1).reduce(0, +)), Double(total) / 2) }
    }
    func testFromNasAndNoDaysOrInvalidGoal() throws {
        let last = try XCTUnwrap(catalog.surahs.last)
        let rows = try XCTUnwrap(try edit(goal(1, 6236, direction: "fromNas"), pace: "verse1").generatedSessions(state: .object([:]), catalog: catalog, preview: true))
        XCTAssertEqual(rows.first?["start"].int, last.start)
        let state: JSONValue = .object(["keep": .bool(true)])
        XCTAssertEqual(try edit(goal(), days: []).applying(to: state, catalog: catalog), state)
        XCTAssertEqual(try edit(goal(1, 9999)).applying(to: state, catalog: catalog), state)
    }
}
