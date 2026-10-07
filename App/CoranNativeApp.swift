import SwiftUI

@main struct CoranNativeApp: App {
    @StateObject private var store: AppStore
    @StateObject private var recitations: RecitationLibrary
    @StateObject private var friends: FriendsLibrary
    @StateObject private var quiz: QuizLibrary
    @StateObject private var reports: ProblemReportLibrary
    @StateObject private var moderation: ModerationLibrary
    @StateObject private var theme = ThemeManager()
    @StateObject private var network = ConnectivityService()
    @StateObject private var reminders = LocalReminderService()
    @Environment(\.scenePhase) private var scenePhase
    init() {
        let client = try? BackendConfiguration.load().client()
        let auth = AuthService(client: client)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-authenticated") {
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--ui-test-difficulty-cache=") }),
               let cacheID = UUID(uuidString: String(argument.dropFirst("--ui-test-difficulty-cache=".count))) {
                _store = StateObject(wrappedValue: AppStore(auth: PreviewAuth(), remote: PreviewRemote(), cache: PreviewDiskCache(id: cacheID)))
            } else {
                _store = StateObject(wrappedValue: AppStore(auth: PreviewAuth(), remote: PreviewRemote(), cache: PreviewCache()))
            }
            _recitations = StateObject(wrappedValue: RecitationLibrary(storage: RecitationStorage(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PreviewRecitations-\(UUID().uuidString)")), remote: ProcessInfo.processInfo.arguments.contains("--ui-test-recitation-feedback") ? PreviewRecitationFeedback() : RecitationRepository(client: nil)))
            let friendsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("PreviewFriends-\(UUID().uuidString)")
            if ProcessInfo.processInfo.arguments.contains("--ui-test-friends") {
                let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, other = "00000000-0000-0000-0000-000000000002"
                let friend = FriendsSnapshot(owner: owner,
                    links: .array([.object(["id": .string("00000000-0000-0000-0000-000000000003"), "requester_id": .string(owner.uuidString), "recipient_id": .string(other), "status": .string("accepted")])]),
                    profiles: .array([.object(["id": .string(other), "display_name": .string("Yassine"), "share_progress": .bool(true)])]),
                    overviews: [other: .object(["id": .string(other), "weekly_verses": .number(28), "weekly_sessions": .number(5), "quran_percent": .number(33), "goal_label": .string("Finir le Hizb 42"), "goal_percent": .number(58)])])
                try? FileManager.default.createDirectory(at: friendsDirectory, withIntermediateDirectories: true)
                if let data = try? JSONEncoder().encode(friend) { try? data.write(to: friendsDirectory.appendingPathComponent(owner.uuidString.lowercased() + ".json")) }
            }
            if ProcessInfo.processInfo.arguments.contains("--ui-test-groups") {
                let owner = "00000000-0000-0000-0000-000000000001", group = "00000000-0000-0000-0000-000000000005", other = "00000000-0000-0000-0000-000000000002"
                let rows: [JSONValue] = [.object(["id": .string(group), "name": .string("Groupe de test"), "owner_id": .string(owner)])]
                let members: [JSONValue] = [(owner, "Moi", "owner"), (other, "Yassine", "member")].map { user, name, role in .object(["group_id": .string(group), "user_id": .string(user), "name": .string(name), "role": .string(role), "accepted_at": .string(ISO8601DateFormatter().string(from: .now))]) }
                try? FileManager.default.createDirectory(at: friendsDirectory, withIntermediateDirectories: true)
                if let data = try? JSONEncoder().encode(rows) { try? data.write(to: friendsDirectory.appendingPathComponent(owner + "-groups.json")) }
                if let data = try? JSONEncoder().encode(members) { try? data.write(to: friendsDirectory.appendingPathComponent(owner + "-group-" + group + ".json")) }
            }
            _friends = StateObject(wrappedValue: FriendsLibrary(client: nil, directory: friendsDirectory))
            if ProcessInfo.processInfo.arguments.contains("--ui-test-quiz") {
                let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, day = LocalCalendar.key(.now)
                let question: JSONValue = .object(["id": .string("00000000-0000-0000-0000-000000000004"), "category": .string("Test technique"), "question": .string("Question de test de l’interface"), "publicationDate": .string(day), "answers": .array(["A", "B", "C"].map { .object(["id": .string($0), "text": .string("Choix " + $0)]) })])
                let cached = QuizCache(owner: owner, data: .object(["day": .string(day), "daily": question, "responses": .array([])]))
                let directory = friendsDirectory.appendingPathComponent("Quiz")
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if let bytes = try? JSONEncoder().encode(cached) { try? bytes.write(to: directory.appendingPathComponent(owner.uuidString.lowercased() + ".json")) }
            }
            _quiz = StateObject(wrappedValue: QuizLibrary(client: nil, directory: friendsDirectory.appendingPathComponent("Quiz")))
            _reports = StateObject(wrappedValue: ProblemReportLibrary(directory: friendsDirectory.appendingPathComponent("Reports")))
            _moderation = StateObject(wrappedValue: ModerationLibrary(remote: ProcessInfo.processInfo.arguments.contains("--ui-test-moderation") ? PreviewModeration() : ModerationRepository(client: nil)))
            return
        }
        #endif
        _store = StateObject(wrappedValue: AppStore(auth: auth, remote: HomeRepository(client: client), cache: LocalStorageService()))
        _recitations = StateObject(wrappedValue: RecitationLibrary(remote: RecitationRepository(client: client)))
        _friends = StateObject(wrappedValue: FriendsLibrary(client: client))
        _quiz = StateObject(wrappedValue: QuizLibrary(client: client))
        _reports = StateObject(wrappedValue: ProblemReportLibrary(client: client))
        _moderation = StateObject(wrappedValue: ModerationLibrary(remote: ModerationRepository(client: client)))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(theme).environmentObject(network).environmentObject(recitations).environmentObject(friends).environmentObject(quiz).environmentObject(reports).environmentObject(moderation).environmentObject(reminders)
                .onOpenURL { url in Task { await store.receive(url) } }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh(); await recitations.synchronize(); await friends.refresh(); await quiz.refresh() } } }
                .onChange(of: store.identity?.id, initial: true) { _, user in Task { await recitations.select(user); await recitations.synchronize() } }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reports.synchronize() } } }
                .onChange(of: scenePhase) { _, phase in if phase == .active { reminders.update(owner: store.identity?.id, settings: ReminderSettings.load(store.snapshot.state), force: true) } }
                .onChange(of: store.identity?.id, initial: true) { _, user in reports.select(user); Task { await reports.synchronize() } }
                .onChange(of: store.identity?.id, initial: true) { _, user in friends.select(user) }
                .onChange(of: store.identity?.id, initial: true) { _, user in moderation.select(user) }
                .onChange(of: store.identity?.id, initial: true) { _, user in quiz.select(user); Task { await quiz.refresh() } }
        }
    }
}
#if DEBUG
@MainActor private final class PreviewRecitationFeedback: RecitationRemote {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    func upload(_ item: Recitation, file: URL) async throws {}
    func list(owner: UUID) async throws -> [Recitation] {
        guard owner == self.owner else { return [] }
        return [Recitation(id: "00000000-0000-0000-0000-000000000020", userID: owner, start: 1, end: 7, durationMs: 60000, createdAt: "2026-10-07T10:00:00Z", storagePath: "\(owner.uuidString.lowercased())/test.m4a", synced: true)]
    }
    func download(_ item: Recitation) async throws -> Data { try fixture() }
    func reviews(_ item: Recitation) async throws -> [RecitationFeedback] {
        [RecitationFeedback(id: "00000000-0000-0000-0000-000000000021", recitation_id: item.id, verse_id: 3, comment: "Observation technique de test", voice_path: "feedback/00000000-0000-0000-0000-000000000002/test.m4a", created_at: "2026-10-07T10:01:00Z", resolved_at: nil)]
    }
    func feedbackAudio(_ item: Recitation, review: RecitationFeedback) async throws -> Data { try fixture() }
    private func fixture() throws -> Data { try Data(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("ReaderTestFixtures/audio.wav")) }
}
@MainActor private final class PreviewModeration: ModerationRemote {
    private var deleted = false
    private var reviewed = false
    private var heard = false
    private let user = "00000000-0000-0000-0000-000000000002"
    private var recitation: JSONValue { .object(["id": .string("rec-test"), "user_id": .string(user), "recording_type": .string("quran"), "start_verse_id": .number(1), "end_verse_id": .number(7), "duration_ms": .number(60000), "storage_path": .string(user + "/rec-test.m4a"), "created_at": .string("2026-10-05T10:00:00Z"), "listened_at": heard ? .string("2026-10-05T10:01:00Z") : .null]) }
    private var message: JSONValue { .object(["id": .string("00000000-0000-0000-0000-000000000007"), "sender_id": .string(user), "body": .string("Message de test à modérer"), "kind": .string("text"), "created_at": .string("2026-10-05T10:00:00Z"), "deleted_at": deleted ? .string("2026-10-05T10:01:00Z") : .null]) }
    private var report: JSONValue { .object(["id": .string("00000000-0000-0000-0000-000000000008"), "reporter_id": .string(user), "reason": .string("Signalement de test"), "excerpt": .string("Message de test à modérer"), "status": .string(reviewed ? "reviewed" : "open"), "created_at": .string("2026-10-05T10:00:00Z")]) }
    func rows(owner: UUID, section: ModerationSection, offset: Int) async throws -> [JSONValue] { offset > 0 ? [] : [section == .recitations ? recitation : section == .messages ? message : report] }
    func profiles(owner: UUID, ids: [String]) async throws -> [JSONValue] { [.object(["id": .string(user), "display_name": .string("Yassine")])] }
    func recording(owner: UUID, id: String) async throws -> JSONValue { recitation }
    func audio(owner: UUID, row: JSONValue) async throws -> Data { try Data(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("ReaderTestFixtures/audio.wav")) }
    func deleteMessage(owner: UUID, id: String) async throws -> JSONValue { deleted = true; return message }
    func resolveReport(owner: UUID, id: String) async throws -> JSONValue { reviewed = true; return report }
    func listened(owner: UUID, id: String) async throws -> JSONValue { heard = true; return recitation }
    func feedback(owner: UUID, recitation: String, id: UUID, comment: String) async throws {}
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws { guard !data.isEmpty else { throw URLError(.cannotDecodeContentData) } }
}
@MainActor private final class PreviewAuth: AuthGateway {
    let cachedIdentity: AccountIdentity? = AccountIdentity(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, email: "preview@example.invalid")
    func signIn(email: String, password: String) async throws -> AccountIdentity { cachedIdentity! }
    func signUp(email: String, password: String) async throws -> AccountIdentity? { cachedIdentity }
    func refresh() async throws -> AccountIdentity { throw URLError(.notConnectedToInternet) }
    func signOut() async throws {}
    func resetPassword(email: String) async throws {}
    func receive(url: URL) async throws -> AccountIdentity { cachedIdentity! }
    func changePassword(_ password: String) async throws {}
}
@MainActor private final class PreviewRemote: HomeRemote {
    func fetch(userID: UUID, cached: HomeSnapshot) async throws -> HomeSnapshot { cached }
}
private struct PreviewCache: HomeCache {
    func load(userID: UUID) throws -> HomeSnapshot? {
        let snapshot = HomeSnapshot(state: .object(["schema":.number(1), "profile":.object(["firstName":.string("Mohamed")]), "lastRead":.object(["verseId":.number(3371), "page":.number(397)]), "goal":.object(["label":.string("Finir le Hizb 42")])]))
        if ProcessInfo.processInfo.arguments.contains("--ui-test-review-queues") {
            let today = LocalCalendar.key(.now), learned = ProgramProjection.addingDays(-1, to: LocalCalendar.key(.now), timeZone: .current)!
            var value = snapshot
            value.state = snapshot.state
                .setting("knowledge", .object(Dictionary(uniqueKeysWithValues: (1...7).map { (String($0), JSONValue.string("perfect")) })))
                .setting("memorizedAt", .object(Dictionary(uniqueKeysWithValues: (4...7).map { (String($0), JSONValue.string(learned)) })))
                .setting("difficultyMarkers", .object(Dictionary(uniqueKeysWithValues: (1...3).map { (String($0), JSONValue.object(["user": .object(["createdAt": .string(today)])])) })))
                .setting("reviewConsolidations", .object(Dictionary(uniqueKeysWithValues: (4...7).map { (String($0), JSONValue.object(["learnedAt": .string(learned), "completed": .object([:])])) })))
                .setting("reviewCycle", .object(["index": .number(1), "startDate": .string(today), "lengthDays": .number(7), "corpus": .array((1...3).map { .number(Double($0)) }), "days": .array([.array((1...3).map { .number(Double($0)) })]), "completed": .array([]), "assignments": .object([today: .number(0)])]))
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-consolidation") {
            let learned = ProgramProjection.addingDays(-1, to: LocalCalendar.key(.now), timeZone: .current)!
            var value = snapshot
            value.state = snapshot.state
                .setting("knowledge", .object(Dictionary(uniqueKeysWithValues: (1...7).map { (String($0), JSONValue.string("perfect")) })))
                .setting("memorizedAt", .object(Dictionary(uniqueKeysWithValues: (1...7).map { (String($0), JSONValue.string(learned)) })))
                .setting("reviewConsolidations", .object(Dictionary(uniqueKeysWithValues: (1...7).map { (String($0), JSONValue.object(["learnedAt": .string(learned), "completed": .object([:])])) })))
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-program") {
            let task: JSONValue = .object(["id": .string("preview-learning"), "start": .number(1), "end": .number(7), "status": .string("todo"), "scheduledDate": .string(LocalCalendar.key(.now))])
            var value = snapshot; value.state = snapshot.state.setting("sessions", .array([task])); return value
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-revision") {
            let ids: [JSONValue] = (1...7).map { .number(Double($0)) }
            let today = LocalCalendar.key(.now)
            var value = snapshot
            value.state = snapshot.state.setting("knowledge", .object(Dictionary(uniqueKeysWithValues: (1...7).map { (String($0), JSONValue.string("perfect")) })))
                .setting("reviewCycle", .object(["index": .number(1), "startDate": .string(today), "lengthDays": .number(7), "corpus": .array(ids), "days": .array([.array(ids)]), "completed": .array([]), "assignments": .object([today: .number(0)])]))
            return value
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-program-edit") {
            var value = snapshot
            value.state = snapshot.state.setting("goal", .object(["label": .string("Al Fâtiha"), "ranges": .array([.object(["start": .number(1), "end": .number(7)])])]))
                .setting("pace", .string("verse3")).setting("learningDays", .array((0...6).map { .number(Double($0)) }))
            return value
        }
        return snapshot
    }
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws {}
}
private struct PreviewDiskCache: HomeCache {
    let storage: LocalStorageService
    init(id: UUID) {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        storage = LocalStorageService(directory: root.appendingPathComponent("UITestDifficulty").appendingPathComponent(id.uuidString))
    }
    func load(userID: UUID) throws -> HomeSnapshot? {
        if let cached = try storage.load(userID: userID) { return cached }
        let seed = try PreviewCache().load(userID: userID)
        if let seed { try storage.save(seed, userID: userID) }
        return seed
    }
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws { try storage.save(snapshot, userID: userID) }
}
#endif
