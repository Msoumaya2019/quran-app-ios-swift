import XCTest
@testable import CoranNative

final class QuizTests: XCTestCase {
    func question(day: String) -> JSONValue {
        .object(["id": .string(UUID().uuidString), "publicationDate": .string(day), "answers": .array([.object(["id": .string("a"), "text": .string("Choix A")]), .object(["id": .string("b"), "text": .string("Choix B")]), .object(["id": .string("c"), "text": .string("Choix C")])])])
    }
    func testOnlyOneImmutableAnswerPerLocalDayAndUnknownChoiceRejected() throws {
        let day = "2026-10-05", q = question(day: "2026-10-05")
        var cache = QuizCache(owner: UUID())
        XCTAssertThrowsError(try cache.answer(q, answerID: "invalid", day: day))
        XCTAssertThrowsError(try cache.answer(q, answerID: "a", day: "2026-10-06"))
        try cache.answer(q, answerID: "a", day: day)
        XCTAssertThrowsError(try cache.answer(q, answerID: "b", day: day))
        XCTAssertEqual(cache.response(day: day)?["selectedAnswerId"].string, "a")
        XCTAssertNil(cache.response(day: "2026-10-06"))
    }
    func testOfflineAnswerSurvivesEncodingWithoutInventingCorrection() throws {
        var cache = QuizCache(owner: UUID())
        try cache.answer(question(day: "2026-10-05"), answerID: "b", day: "2026-10-05")
        let reopened = try JSONDecoder().decode(QuizCache.self, from: JSONEncoder().encode(cache))
        XCTAssertEqual(reopened.pending, cache.pending)
        XCTAssertNil(reopened.response(day: "2026-10-05")?["isCorrect"].bool)
        XCTAssertEqual(reopened.response(day: "2026-10-05")?["pending"].bool, true)
    }
    func testServerResponseTakesPriorityOverPendingResponseFromOtherDevice() throws {
        var cache = QuizCache(owner: UUID())
        try cache.answer(question(day: "2026-10-05"), answerID: "a", day: "2026-10-05")
        cache.data = .object(["responses": .array([.object(["day": .string("2026-10-05"), "selectedAnswerId": .string("c"), "isCorrect": .bool(false)])])])
        XCTAssertEqual(cache.response(day: "2026-10-05")?["selectedAnswerId"].string, "c")
    }
}
