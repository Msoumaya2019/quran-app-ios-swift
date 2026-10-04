import Foundation
import Supabase

@MainActor protocol DailyQuizRemote {
    func snapshot(owner: UUID, day: String) async throws -> JSONValue
    func answer(owner: UUID, value: QuizPendingAnswer) async throws
}
@MainActor final class QuizRepository: DailyQuizRemote {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    private struct DayArgs: Encodable { let p_day: String }
    private struct AnswerArgs: Encodable { let p_question: String; let p_answer: String; let p_day: String; let p_answered_at: String }
    private func authorized(_ owner: UUID) async throws {
        guard try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
    }
    func snapshot(owner: UUID, day: String) async throws -> JSONValue {
        try await authorized(owner)
        return try await client.rpc("quiz_snapshot", params: DayArgs(p_day: day)).execute().value
    }
    func answer(owner: UUID, value: QuizPendingAnswer) async throws {
        try await authorized(owner)
        guard let id = value.question["id"].string, UUID(uuidString: id) != nil else { throw URLError(.badServerResponse) }
        try await client.rpc("quiz_answer_daily", params: AnswerArgs(p_question: id, p_answer: value.answerID, p_day: value.day, p_answered_at: value.answeredAt)).execute()
    }
}
