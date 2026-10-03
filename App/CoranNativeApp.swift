import SwiftUI

@main struct CoranNativeApp: App {
    @StateObject private var store: AppStore
    @StateObject private var theme = ThemeManager()
    @StateObject private var network = ConnectivityService()
    @Environment(\.scenePhase) private var scenePhase
    init() {
        let client = try? BackendConfiguration.load().client()
        let auth = AuthService(client: client)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-authenticated") {
            _store = StateObject(wrappedValue: AppStore(auth: PreviewAuth(), remote: PreviewRemote(), cache: PreviewCache()))
            return
        }
        #endif
        _store = StateObject(wrappedValue: AppStore(auth: auth, remote: HomeRepository(client: client), cache: LocalStorageService()))
    }
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).environmentObject(theme).environmentObject(network)
                .onOpenURL { url in Task { await store.receive(url) } }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.refresh() } } }
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
    func load(userID: UUID) throws -> HomeSnapshot? { HomeSnapshot(state: .object(["schema":.number(1), "profile":.object(["firstName":.string("Mohamed")]), "lastRead":.object(["verseId":.number(3371), "page":.number(397)]), "goal":.object(["label":.string("Finir le Hizb 42")])])) }
    func save(_ snapshot: HomeSnapshot, userID: UUID) throws {}
}
#endif
