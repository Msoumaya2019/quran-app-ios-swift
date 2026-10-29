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
    @Published private(set) var solo: JSONValue = .null
    @Published private(set) var soloResponses: [String: JSONValue] = [:]
    private let client: SupabaseClient?
    private let soloRemote: SoloQuizRemote?
    private let dailyRemote: DailyQuizRemote?
    private let directory: URL
    private var generation = UUID()
    init(client: SupabaseClient?, directory: URL? = nil, dailyRemote: DailyQuizRemote? = nil, soloRemote: SoloQuizRemote? = nil) {
        self.soloRemote = soloRemote ?? client.map { QuizRepository(client: $0) }
        self.client = client
        self.dailyRemote = dailyRemote ?? client.map { QuizRepository(client: $0) }
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
        isAdmin = false; adminQuestions = []; adminSets = []; solo = .null; soloResponses = [:]
        cache = owner.map { QuizCache(owner: $0) }
        if let owner, let bytes = try? Data(contentsOf: file(owner)), let stored = try? JSONDecoder().decode(QuizCache.self, from: bytes), stored.owner == owner { cache = stored }
    }
    func answer(_ question: JSONValue, answerID: String) {
        guard var next = cache else { return }
        do { try next.answer(question, answerID: answerID, day: LocalCalendar.key(.now)); try save(next); message = nil }
        catch { message = "La réponse n’a pas pu être enregistrée." }
    }
    private struct ResponsesArgs: Encodable { let p_question: String?; let p_offset: Int }
    func startSolo() async {
        guard !actionBusy, let owner = cache?.owner, let soloRemote else { message = "Connexion nécessaire pour commencer une série."; return }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            let result = try await soloRemote.startSolo(owner: owner)
            guard token == generation else { return }
            guard UUID(uuidString: result["id"].string ?? "") != nil, (1...10).contains(result["questions"].array.count),
                  Set(result["questions"].array.compactMap { $0["id"].string }).count == result["questions"].array.count else { throw URLError(.cannotParseResponse) }
            solo = result; soloResponses = [:]; message = nil
        } catch { if token == generation { message = "Série indisponible. Vérifie la connexion et l’installation du SQL quiz-solo-admin." } }
    }
    func answerSolo(question: JSONValue, answerID: String) async {
        guard !actionBusy, let owner = cache?.owner, let soloRemote, let run = solo["id"].string,
              let id = question["id"].string, solo["questions"].array.contains(where: { $0["id"].string == id }),
              question["answers"].array.contains(where: { $0["id"].string == answerID }), soloResponses[id] == nil else { return }
        let token = generation; actionBusy = true
        defer { if token == generation { actionBusy = false } }
        do {
            let response = try await soloRemote.answerSolo(owner: owner, run: run, question: id, answer: answerID)
            guard token == generation, solo["id"].string == run else { return }
            guard response["question"]["id"].string == id, response["selectedAnswerId"].string != nil, response["isCorrect"].bool != nil else { throw URLError(.cannotParseResponse) }
            soloResponses[id] = response; message = nil
        } catch { if token == generation { message = "Réponse non confirmée. Réessaie : le serveur conserve toujours ton premier choix." } }
    }
    func adminResponses(questionID: String?, offset: Int) async throws -> [JSONValue] {
        guard isAdmin, let owner = cache?.owner, let client else { throw URLError(.userAuthenticationRequired) }
        let token = generation
        guard try await client.auth.session.user.id == owner, token == generation else { throw URLError(.userAuthenticationRequired) }
        let result: JSONValue = try await client.rpc("quiz_admin_responses", params: ResponsesArgs(p_question: questionID, p_offset: max(0, offset))).execute().value
        guard token == generation, isAdmin else { throw CancellationError() }
        return result.array
    }
    private struct ChallengeArgs: Encodable { let p_opponent: String; let p_count: Int; let p_set: String? }
    private struct ChallengeAnswerArgs: Encodable { let p_challenge: String; let p_question: String; let p_answer: String }
    func checkAdmin() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-moderation") || ProcessInfo.processInfo.arguments.contains("--ui-test-editorial") { isAdmin = true; return }
        #endif
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
        guard !loading, let initial = cache, let remote = dailyRemote else { return }
        let token = generation; loading = true
        defer { if token == generation { loading = false } }
        do {
            guard token == generation else { return }
            for pending in initial.pending {
                do {
                    try await remote.answer(owner: initial.owner, value: pending)
                    guard token == generation else { return }
                } catch {
                    guard token == generation else { return }
                    // A rejected, edited question must not block other dates. Network
                    // failures stop the drain, while the local operation remains intact.
                    if let network = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .userAuthenticationRequired].contains(network.code) { break }
                }
            }
            let data = try await remote.snapshot(owner: initial.owner, day: LocalCalendar.key(.now))
            guard token == generation, var next = cache else { return }
            let confirmedDays = Set(data["responses"].array.compactMap { $0["day"].string })
            next.data = data; next.pending.removeAll { confirmedDays.contains($0.day) }; try save(next)
            message = next.pending.isEmpty ? nil : "Certaines réponses attendent encore une confirmation. Elles restent conservées sur cet appareil."
        } catch {
            guard token == generation else { return }
            message = "Actualisation du Quiz indisponible. Tes réponses restent enregistrées et seront réessayées."
        }
    }
}
