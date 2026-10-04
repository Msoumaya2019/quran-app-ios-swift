import XCTest
@testable import CoranNative

final class ProgressTests: XCTestCase {
    func testOnlyKnownVersesCountAndOverlappingGoalRangesAreNotCountedTwice() {
        let state: JSONValue = .object(["knowledge": .object(["1": .string("perfect"), "2": .string("review"), "3": .string("unknown"), "6237": .string("perfect")]), "goal": .object(["ranges": .array([.object(["start": .number(1), "end": .number(2)]), .object(["start": .number(2), "end": .number(3)])])])])
        let p = ProgressProjection(state: state)
        XCTAssertEqual(p.known, [1, 2]); XCTAssertEqual(p.goalIDs.count, 3)
        XCTAssertEqual(p.goalRatio, 2.0 / 3.0, accuracy: 0.001)
    }
    func testExpiredChallengesAndPendingDailyAnswersDoNotEarnQuizStatistics() {
        let owner = UUID(), other = UUID()
        let answers: JSONValue = .array([.object(["userId": .string(owner.uuidString), "isCorrect": .bool(true)]), .object(["userId": .string(other.uuidString), "isCorrect": .bool(false)])])
        let row: JSONValue = .object(["creatorId": .string(owner.uuidString), "opponentId": .string(other.uuidString), "status": .string("expired"), "answers": answers])
        let stats = QuizStatistics(data: .object(["responses": .array([]), "challenges": .array([row])]), owner: owner)
        XCTAssertEqual(stats.dailyTotal, 0); XCTAssertEqual(stats.completed.count, 0); XCTAssertEqual(stats.wins, 0)
        let finished = QuizStatistics(data: .object(["responses": .array([.object(["isCorrect": .bool(true)])]), "challenges": .array([row.setting("status", .string("completed"))])]), owner: owner)
        XCTAssertEqual(finished.wins, 1); XCTAssertEqual(finished.successPercent, 100)
    }
}
