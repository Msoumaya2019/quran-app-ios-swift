import XCTest
@testable import CoranNative

@MainActor final class QuizSoloTests: XCTestCase {
    private func library(_ remote: FakeSoloRemote) -> QuizLibrary {
        let library = QuizLibrary(client: nil, directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), soloRemote: remote)
        library.select(UUID()); return library
    }
    func testSoloDoesNotExposeCorrectionBeforeConfirmedAnswerAndCannotChangeAnswer() async {
        let remote = FakeSoloRemote(), quiz = library(FakeSoloRemote())
        let tested = library(remote)
        await tested.startSolo()
        XCTAssertNil(tested.solo["questions"].array.first?["correctAnswerId"].string)
        let question = tested.solo["questions"].array[0]
        await tested.answerSolo(question: question, answerID: "A")
        XCTAssertEqual(tested.soloResponses[remote.questionID]?["selectedAnswerId"].string, "A")
        await tested.answerSolo(question: question, answerID: "B")
        XCTAssertEqual(remote.answerCalls, 1)
        XCTAssertNil(quiz.solo["id"].string)
    }
    func testFailedConfirmationKeepsQuestionAndRetriesServerFirstChoice() async {
        let remote = FakeSoloRemote(), quiz = library(remote)
        await quiz.startSolo(); let question = quiz.solo["questions"].array[0]
        remote.failOnce = true
        await quiz.answerSolo(question: question, answerID: "A")
        XCTAssertNotNil(quiz.message); XCTAssertTrue(quiz.soloResponses.isEmpty)
        await quiz.answerSolo(question: question, answerID: "B")
        XCTAssertEqual(quiz.soloResponses[remote.questionID]?["selectedAnswerId"].string, "A")
    }
    func testAccountSwitchDiscardsInFlightSoloResponse() async {
        let remote = FakeSoloRemote(), quiz = library(remote)
        await quiz.startSolo(); let question = quiz.solo["questions"].array[0]
        remote.beforeResponse = { quiz.select(UUID()) }
        await quiz.answerSolo(question: question, answerID: "A")
        XCTAssertTrue(quiz.soloResponses.isEmpty); XCTAssertEqual(quiz.solo, .null)
    }
    func testMalformedDuplicateSeriesIsRejected() async {
        let remote = FakeSoloRemote(), quiz = library(remote)
        remote.duplicate = true
        await quiz.startSolo()
        XCTAssertEqual(quiz.solo, .null); XCTAssertNotNil(quiz.message)
    }
}

@MainActor private final class FakeSoloRemote: SoloQuizRemote {
    let questionID = UUID().uuidString
    var answerCalls = 0, failOnce = false, duplicate = false
    var firstChoice: String?
    var beforeResponse: (() -> Void)?
    var question: JSONValue { .object(["id": .string(questionID), "question": .string("Technical fixture"), "answers": .array(["A", "B", "C"].map { .object(["id": .string($0), "text": .string($0)]) })]) }
    func startSolo(owner: UUID) async throws -> JSONValue {
        .object(["id": .string(UUID().uuidString), "questions": .array(duplicate ? [question, question] : [question])])
    }
    func answerSolo(owner: UUID, run: String, question id: String, answer: String) async throws -> JSONValue {
        answerCalls += 1; if firstChoice == nil { firstChoice = answer }
        if failOnce { failOnce = false; throw URLError(.networkConnectionLost) }
        beforeResponse?()
        return .object(["question": question.setting("correctAnswerId", .string("A")), "selectedAnswerId": .string(firstChoice!), "isCorrect": .bool(firstChoice == "A")])
    }
}
