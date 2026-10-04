import Foundation
import Supabase

@MainActor final class QuizLibrary: ObservableObject {
    @Published private(set) var cache: QuizCache?
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published private(set) var actionBusy = false
    @Published private(set) var isAdmin = false
    @Published private(set) var adminQuestions: [JSONValue] = []
    @Published private(set) var adminSets: [JSONValue] = []
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
        generation = UUID(); loading = false; actionBusy = false; message = nil
        isAdmin = false; adminQuestions = []; adminSets = []
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
    private struct ChallengeArgs: Encodable { let p_opponent: String; let p_count: Int; let p_set: String? }
    private struct ChallengeAnswerArgs: Encodable { let p_challenge: String; let p_question: String; let p_answer: String }
    func checkAdmin() async {
        guard let owner = cache?.owner, let client else { return }
        let token = generation
        do {
            guard try await client.auth.session.user.id == owner else { return }
            struct Row: Decodable { let user_id: UUID }
            let rows: [Row] = try await client.from("app_admins").select("user_id").eq("user_id", value: owner.uuidString).limit(1).execute().value
            guard token == generation else { return }; isAdmin = rows.contains { $0.user_id == owner }
        } catch { if token == generation { isAdmin = false } }
    }
    func refreshAdmin() async {
        guard isAdmin, let client, let owner = cache?.owner else { return }
        let token = generation
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return }
            async let questions: JSONValue = client.rpc("quiz_admin_list").execute().value
            async let sets: JSONValue = client.rpc("quiz_admin_sets").execute().value
            let result = try await (questions, sets)
            guard token == generation else { return }
            adminQuestions = result.0.array; adminSets = result.1.array; message = nil
        } catch { if token == generation { message = "Administration indisponible. Vérifie la connexion et les droits de ton compte." } }
    }
    private struct QuestionArgs: Encodable { let p_question: JSONValue }
    private struct SetArgs: Encodable { let p_set: JSONValue }
    private struct DeleteArgs: Encodable { let p_id: String }
    func adminSave(_ value: JSONValue, isSet: Bool = false) async -> Bool {
        guard !actionBusy, isAdmin, let client, let owner = cache?.owner else { return false }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return false }
            if isSet { let _: UUID = try await client.rpc("quiz_admin_save_set", params: SetArgs(p_set: value)).execute().value }
            else { let _: UUID = try await client.rpc("quiz_admin_save", params: QuestionArgs(p_question: value)).execute().value }
            guard token == generation else { return false }; await refreshAdmin(); return true
        } catch { if token == generation { message = "Enregistrement refusé. Vérifie les champs obligatoires, la date et la connexion." }; return false }
    }
    func adminDelete(_ id: String, isSet: Bool) async {
        guard !actionBusy, isAdmin, let client, let owner = cache?.owner else { return }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return }
            try await client.rpc(isSet ? "quiz_admin_delete_set" : "quiz_admin_delete", params: DeleteArgs(p_id: id)).execute()
            guard token == generation else { return }; await refreshAdmin()
        } catch { if token == generation { message = "La suppression n’a pas été confirmée." } }
    }
    func createChallenge(friend: String, count: Int, set: String?) async {
        guard !actionBusy, let owner = cache?.owner, let client, UUID(uuidString: friend) != nil, [5, 10].contains(count) else { message = "Connexion nécessaire pour lancer ce défi."; return }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return }
            let _: UUID = try await client.rpc("quiz_create_challenge", params: ChallengeArgs(p_opponent: friend, p_count: count, p_set: set)).execute().value
            guard token == generation else { return }
            message = "Défi créé."; await refresh()
        } catch { if token == generation { message = "Défi indisponible. Vérifie la connexion et le nombre de questions disponibles." } }
    }
    func answerChallenge(challenge: String, question: String, answer: String) async {
        guard !actionBusy, let owner = cache?.owner, let client else { message = "Connexion nécessaire pour répondre au défi."; return }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return }
            try await client.rpc("quiz_answer_challenge", params: ChallengeAnswerArgs(p_challenge: challenge, p_question: question, p_answer: answer)).execute()
            guard token == generation else { return }
            await refresh()
        } catch { if token == generation { message = "Réponse non confirmée. Reconnecte-toi pour vérifier le défi avant de continuer." } }
    }
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
            message = "Actualisation du Quiz indisponible. Tes réponses restent enregistrées et seront réessayées."
        }
    }
}
