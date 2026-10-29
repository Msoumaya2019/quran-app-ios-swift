#if DEBUG
import Foundation

/// Technical fixtures only; never used by Release or production catalogue.
@MainActor final class SoloQuizPreviewRemote: SoloQuizRemote {
    private let run = UUID().uuidString
    private let questionID = UUID().uuidString
    private var selected: String?
    private var question: JSONValue { .object(["id": .string(questionID), "category": .string("Test technique"), "question": .string("Question technique solo"), "answers": .array(["A", "B", "C"].map { .object(["id": .string($0), "text": .string("Choix " + $0)]) })]) }
    func startSolo(owner: UUID) async throws -> JSONValue { selected = nil; return .object(["id": .string(run), "questions": .array([question])]) }
    func answerSolo(owner: UUID, run: String, question id: String, answer: String) async throws -> JSONValue {
        guard id == questionID, run == self.run else { throw URLError(.badServerResponse) }
        if selected == nil { selected = answer }
        return .object(["question": question.setting("correctAnswerId", .string("A")).setting("explanation", .string("Correction technique enregistrée.")), "selectedAnswerId": .string(selected!), "isCorrect": .bool(selected == "A")])
    }
}
#endif
