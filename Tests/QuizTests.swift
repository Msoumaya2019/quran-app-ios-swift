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
    func testChallengeDoesNotExposeScoreUntilBothPlayersFinishAndExpiryHasNoWinner() {
        let owner = UUID(), other = UUID(), questionID = UUID().uuidString
        let question: JSONValue = .object(["id": .string(questionID)])
        let answers: JSONValue = .array([.object(["userId": .string(owner.uuidString), "questionId": .string(questionID), "isCorrect": .bool(true)])])
        let base: [String: JSONValue] = ["creatorId": .string(owner.uuidString), "opponentId": .string(other.uuidString), "opponentName": .string("Ami"), "questions": .array([question]), "answers": answers, "expiresAt": .string("2099-01-01T00:00:00Z")]
        var value = base; value["status"] = .string("pending")
        let pending = QuizChallengeProjection(value: .object(value), owner: owner)
        XCTAssertNil(pending.score(user: owner.uuidString)); XCTAssertNil(pending.next)
        XCTAssertEqual(pending.status, "En attente de l’ami")
        value["status"] = .string("expired")
        let expired = QuizChallengeProjection(value: .object(value), owner: owner)
        XCTAssertTrue(expired.expired); XCTAssertNil(expired.score(user: owner.uuidString))
        value["status"] = .string("completed")
        XCTAssertEqual(QuizChallengeProjection(value: .object(value), owner: owner).score(user: owner.uuidString), 1)
    }
    @MainActor func testLostServerConfirmationRetriesOnceWithoutLosingLocalAnswer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let owner = UUID(), day = LocalCalendar.key(.now), q = question(day: LocalCalendar.key(.now))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(QuizCache(owner: owner, data: .object(["day": .string(day), "daily": q]))).write(to: directory.appendingPathComponent(owner.uuidString.lowercased() + ".json"))
        let remote = FakeDailyQuizRemote(question: q)
        let library = QuizLibrary(client: nil, directory: directory, dailyRemote: remote)
        library.select(owner); library.answer(q, answerID: "a"); await library.refresh()
        XCTAssertEqual(library.cache?.pending.count, 1)
        let reopened = QuizLibrary(client: nil, directory: directory, dailyRemote: remote)
        reopened.select(owner); await reopened.refresh(); await reopened.refresh()
        XCTAssertEqual(reopened.cache?.pending.count, 0); XCTAssertEqual(remote.inserts, 1)
        XCTAssertEqual(reopened.cache?.response(day: day)?["isCorrect"].bool, true)
        reopened.select(UUID()); XCTAssertEqual(reopened.cache?.data, .null)
        reopened.select(owner); XCTAssertEqual(reopened.cache?.response(day: day)?["selectedAnswerId"].string, "a")
    }
    @MainActor func testRejectedOldQuestionDoesNotBlockTodaysAnswerOrSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let owner = UUID(), day = LocalCalendar.key(.now), old = question(day: "2000-01-01"), today = question(day: LocalCalendar.key(.now))
        var seed = QuizCache(owner: owner)
        try seed.answer(old, answerID: "a", day: "2000-01-01")
        try seed.answer(today, answerID: "b", day: day)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(seed).write(to: directory.appendingPathComponent(owner.uuidString.lowercased() + ".json"))
        let library = QuizLibrary(client: nil, directory: directory, dailyRemote: RejectOldDailyRemote(question: today))
        library.select(owner); await library.refresh()
        XCTAssertEqual(library.cache?.pending.count, 1)
        XCTAssertEqual(library.cache?.pending.first?.day, "2000-01-01")
        XCTAssertEqual(library.cache?.data["day"].string, day)
        XCTAssertEqual(library.cache?.response(day: day)?["selectedAnswerId"].string, "b")
    }
}

@MainActor private final class FakeDailyQuizRemote: DailyQuizRemote {
    let question: JSONValue
    var saved: QuizPendingAnswer?
    var inserts = 0
    var lostConfirmation = false
    init(question: JSONValue) { self.question = question }
    func answer(owner: UUID, value: QuizPendingAnswer) async throws {
        if saved == nil { saved = value; inserts += 1; lostConfirmation = true; throw URLError(.networkConnectionLost) }
    }
    func snapshot(owner: UUID, day: String) async throws -> JSONValue {
        if lostConfirmation { lostConfirmation = false; throw URLError(.networkConnectionLost) }
        let responses: [JSONValue] = saved.map { [.object(["day": .string($0.day), "selectedAnswerId": .string($0.answerID), "isCorrect": .bool(true), "question": question.setting("correctAnswerId", .string("a"))])] } ?? []
        return .object(["day": .string(day), "daily": question, "responses": .array(responses)])
    }
}

@MainActor private final class RejectOldDailyRemote: DailyQuizRemote {
    struct Rejected: Error {}
    let question: JSONValue
    var response: QuizPendingAnswer?
    init(question: JSONValue) { self.question = question }
    func answer(owner: UUID, value: QuizPendingAnswer) async throws {
        guard value.question["id"].string == question["id"].string else { throw Rejected() }; response = value
    }
    func snapshot(owner: UUID, day: String) async throws -> JSONValue {
        let rows: [JSONValue] = response.map { [.object(["day": .string($0.day), "selectedAnswerId": .string($0.answerID), "question": question, "isCorrect": .bool(false)])] } ?? []
        return .object(["day": .string(day), "daily": question, "responses": .array(rows)])
    }
}
