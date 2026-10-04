import Foundation
import Combine

@MainActor final class RecitationLibrary: ObservableObject {
    @Published private(set) var items: [Recitation] = []
    @Published private(set) var syncing = false
    @Published private(set) var message: String?
    private(set) var owner: UUID?
    private let storage: RecitationStorage
    private let remote: any RecitationRemote
    private var generation = 0
    private var inFlight: Set<UUID> = []
    init(storage: RecitationStorage = RecitationStorage(), remote: any RecitationRemote) { self.storage = storage; self.remote = remote }
    func select(_ user: UUID?) async {
        if owner != user { generation += 1; owner = user; items = []; message = nil; syncing = false }
        guard let user else { return }
        let token = generation
        do { let local = try await storage.list(owner: user); guard token == generation else { return }; items = local }
        catch { guard token == generation else { return }; message = "Les enregistrements locaux n’ont pas pu être chargés." }
    }
    func save(source: URL, start: Int, end: Int, durationMs: Int, user: UUID) async throws {
        guard owner == user else { throw URLError(.userAuthenticationRequired) }
        let token = generation
        _ = try await storage.save(source: source, start: start, end: end, durationMs: durationMs, owner: user)
        let local = try await storage.list(owner: user)
        guard token == generation else { return }
        items = local; message = "Récitation enregistrée sur cet iPhone."
    }
    func synchronize() async {
        guard let user = owner, !inFlight.contains(user) else { return }
        let token = generation
        inFlight.insert(user); syncing = true
        defer { inFlight.remove(user); if token == generation { syncing = false } }
        do {
            for item in try await storage.list(owner: user) where !item.synced {
                guard token == generation else { return }
                let file = try await storage.file(for: item)
                try await remote.upload(item, file: file)
                try await storage.confirm(item)
            }
            guard token == generation else { return }
            let incoming = try await remote.list(owner: user)
            guard token == generation else { return }
            try await storage.merge(incoming, owner: user)
            let local = try await storage.list(owner: user)
            guard token == generation else { return }
            items = local; message = nil
        } catch {
            guard token == generation else { return }
            let local = try? await storage.list(owner: user)
            guard token == generation else { return }
            items = local ?? items
            message = "Synchronisation indisponible. Tes enregistrements restent sur cet iPhone et seront réessayés à la reconnexion."
        }
    }
    func playable(_ item: Recitation) async throws -> URL {
        guard owner == item.userID else { throw URLError(.userAuthenticationRequired) }
        let token = generation
        if let file = try? await storage.file(for: item) { guard token == generation else { throw CancellationError() }; return file }
        let data = try await remote.download(item)
        guard token == generation else { throw CancellationError() }
        let file = try await storage.cacheAudio(data, for: item)
        let local = try await storage.list(owner: item.userID)
        guard token == generation else { throw CancellationError() }
        items = local
        return file
    }
}
