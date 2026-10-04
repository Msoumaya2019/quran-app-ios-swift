import Foundation
import Supabase

@MainActor final class QuizLibrary: ObservableObject {
    @Published private(set) var cache: QuizCache?
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    private let client: SupabaseClient?
    private let directory: URL
    private var generation = UUID()
    init(client: SupabaseClient?, directory: URL? = nil) {
        self.client = client
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Quiz")
    }
    private func file(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased() + ".json") }
    private func save(_ value: QuizCache) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file(value.owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache = value
    }
    func select(_ owner: UUID?) {
        guard cache?.owner != owner else { return }
        generation = UUID(); loading = false; message = nil
        cache = owner.map { QuizCache(owner: $0) }
        if let owner, let bytes = try? Data(contentsOf: file(owner)), let stored = try? JSONDecoder().decode(QuizCache.self, from: bytes), stored.owner == owner { cache = stored }
    }
    func answer(_ question: JSONValue, answerID: String) {
        guard var next = cache else { return }
        do { try next.answer(question, answerID: answerID, day: LocalCalendar.key(.now)); try save(next); message = nil }
        catch { message = "La réponse n’a pas pu être enregistrée." }
    }
    private struct DayArgs: Encodable { let p_day: String }
    private struct AnswerArgs: Encodable { let p_question: String; let p_answer: String; let p_day: String; let p_answered_at: String }
    func refresh() async {
        guard !loading, let initial = cache, let client else { return }
        let token = generation; loading = true
        defer { if token == generation { loading = false } }
        do {
            guard try await client.auth.session.user.id == initial.owner else { throw URLError(.userAuthenticationRequired) }
            guard token == generation else { return }
            while let pending = cache?.pending.first {
                guard let questionID = pending.question["id"].string, UUID(uuidString: questionID) != nil else { throw URLError(.badServerResponse) }
                try await client.rpc("quiz_answer_daily", params: AnswerArgs(p_question: questionID, p_answer: pending.answerID, p_day: pending.day, p_answered_at: pending.answeredAt)).execute()
                // Keep the durable operation until the authoritative snapshot confirms it.
                let data: JSONValue = try await client.rpc("quiz_snapshot", params: DayArgs(p_day: LocalCalendar.key(.now))).execute().value
                guard token == generation, var next = cache else { return }
                guard data["responses"].array.contains(where: { $0["day"].string == pending.day }) else { throw URLError(.badServerResponse) }
                next.data = data; next.pending.removeAll { $0.day == pending.day }; try save(next)
            }
            let data: JSONValue = try await client.rpc("quiz_snapshot", params: DayArgs(p_day: LocalCalendar.key(.now))).execute().value
            guard token == generation, var next = cache else { return }
            next.data = data; try save(next); message = nil
        } catch {
            guard token == generation else { return }
            message = "Quiz hors connexion : les réponses enregistrées seront synchronisées."
        }
    }
}
