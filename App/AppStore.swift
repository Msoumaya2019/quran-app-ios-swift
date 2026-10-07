import Foundation
import SwiftUI

@MainActor final class AppStore: ObservableObject {
    @Published private(set) var identity: AccountIdentity?
    @Published private(set) var snapshot = HomeSnapshot()
    @Published var message: String?
    @Published private(set) var isRefreshing = false
    @Published var passwordRecovery = false
    let catalog: QuranCatalog
    private let auth: any AuthGateway
    private let remote: any HomeRemote
    private let cache: any HomeCache
    private var generation = 0
    private var refreshingGeneration: Int?
    @discardableResult func readerChange(_ operation: ReaderOperation) -> Bool {
        guard let userID = identity?.id else { return false }
        var next = snapshot
        next.state = operation.applying(to: next.state, catalog: catalog)
        if [.program, .reviewSchedule, .verseStudy, .reminders].contains(operation.kind), next.state == snapshot.state { return false }
        var queue = next.readerOperations ?? []
        // Keep the latest resume/source operation; bookmark tombstones retain their order.
        if operation.kind == .reading { queue.removeAll { $0.kind == .reading && $0.page == operation.page && $0.source == operation.source } }
        if operation.kind == .source { queue.removeAll { $0.kind == .source } }
        if operation.kind == .reciter { queue.removeAll { $0.kind == .reciter } }
        queue.append(operation); next.readerOperations = queue
        do { try cache.save(next, userID: userID); snapshot = next; return true }
        catch { message = "Impossible d’enregistrer cette modification sur l’appareil."; return false }
    }
    init(auth: any AuthGateway, remote: any HomeRemote, cache: any HomeCache, catalog: QuranCatalog = QuranCatalog()) {
        self.auth = auth; self.remote = remote; self.cache = cache; self.catalog = catalog
        identity = auth.cachedIdentity
        if let id = identity?.id { snapshot = (try? cache.load(userID: id)) ?? HomeSnapshot() }
    }
    func start() async { await refresh() }
    private func use(_ user: AccountIdentity) {
        generation += 1; identity = user
        snapshot = (try? cache.load(userID: user.id)) ?? HomeSnapshot()
        message = nil
    }
    func signIn(email: String, password: String) async throws { use(try await auth.signIn(email: email, password: password)); await refresh() }
    func signUp(email: String, password: String) async throws -> Bool {
        guard let user = try await auth.signUp(email: email, password: password) else { return false }
        use(user); await refresh(); return true
    }
    func resetPassword(email: String) async throws { try await auth.resetPassword(email: email) }
    func receive(_ url: URL) async {
        do {
            use(try await auth.receive(url: url))
            passwordRecovery = url.fragment?.contains("type=recovery") == true || url.query?.contains("type=recovery") == true
            await refresh()
        } catch { message = "Ce lien est invalide ou expiré. Demande un nouveau lien de connexion." }
    }
    func updatePassword(_ password: String) async throws { try await auth.changePassword(password); passwordRecovery = false }
    func signOut() async throws {
        try await auth.signOut()
        generation += 1; identity = nil; snapshot = HomeSnapshot(); message = nil
    }
    func refresh() async {
        prepareReviews()
        guard let original = identity, refreshingGeneration != generation else { return }
        let token = generation
        refreshingGeneration = token; isRefreshing = true
        defer { if refreshingGeneration == token { refreshingGeneration = nil; isRefreshing = false } }
        do {
            let valid = try await auth.refresh()
            guard generation == token, valid.id == original.id else { return }
            let operations = snapshot.readerOperations ?? []
            if !operations.isEmpty {
                try await remote.syncReader(userID: original.id, operations: operations, catalog: catalog)
                guard generation == token else { return }
                let confirmed = Set(operations.map(\.id))
                snapshot.readerOperations?.removeAll { confirmed.contains($0.id) }
                try cache.save(snapshot, userID: original.id)
            }
            var next = try await remote.fetch(userID: original.id, cached: snapshot)
            guard generation == token, identity?.id == original.id else { return }
            next.readerOperations = snapshot.readerOperations
            for operation in next.readerOperations ?? [] { next.state = operation.applying(to: next.state, catalog: catalog) }
            try cache.save(next, userID: original.id)
            snapshot = next; message = nil
            prepareReviews()
        } catch {
            guard generation == token else { return }
            // The local session and cached UI survive refresh/network/server failures.
            message = "Synchronisation indisponible. Tes données locales restent accessibles. Réessaie lorsque la connexion revient."
        }
    }
    func prepareReviews(now: Date = .now, timeZone: TimeZone = .current) {
        guard identity != nil else { return }
        let change = RevisionScheduleChange(now: now, timeZone: timeZone)
        guard change.applying(to: snapshot.state, catalog: catalog) != snapshot.state else { return }
        var operation = ReaderOperation(kind: .reviewSchedule, verseID: 1, page: 1, source: "", date: now)
        operation.reviewSchedule = change
        readerChange(operation)
    }
}
