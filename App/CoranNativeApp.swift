import SwiftUI

@main struct CoranNativeApp: App {
    @StateObject private var store: AppStore
    @StateObject private var recitations: RecitationLibrary
    @StateObject private var theme = ThemeManager()
    @StateObject private var network = ConnectivityService()
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
            _recitations = StateObject(wrappedValue: RecitationLibrary(storage: RecitationStorage(directory: FileManager.default.temporaryDirectory.appendingPathComponent("PreviewRecitations-\(UUID().uuidString)")), remote: RecitationRepository(client: nil)))
            return
        }
        #endif
        _store = StateObject(wrappedValue: AppStore(auth: auth, remote: HomeRepository(client: client), cache: LocalStorageService()))
        _recitations = StateObject(wrappedValue: RecitationLibrary(remote: RecitationRepository(client: client)))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(theme).environmentObject(network).environmentObject(recitations)
                .onOpenURL { url in Task { await store.receive(url) } }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh(); await recitations.synchronize() } } }
                .onChange(of: store.identity?.id, initial: true) { _, user in Task { await recitations.select(user); await recitations.synchronize() } }
        }
    }
}
#if DEBUG
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
