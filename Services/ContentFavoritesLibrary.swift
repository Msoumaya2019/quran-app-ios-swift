import Foundation
import Combine
import Supabase

struct ContentFavoriteChange: Codable, Sendable {
    var id = UUID()
    let contentID: String
    let enabled: Bool
}
struct ContentFavoritesCache: Codable, Sendable {
    let owner: UUID
    var ids: [String] = []
    var contents: [DailyContent] = []
    var pending: [ContentFavoriteChange] = []
}
@MainActor protocol ContentFavoritesRemote {
    func load(owner: UUID) async throws -> ContentFavoritesCache
    func set(owner: UUID, change: ContentFavoriteChange) async throws
}
@MainActor final class ContentFavoritesRepository: ContentFavoritesRemote {
    private let client: SupabaseClient?
    init(client: SupabaseClient?) { self.client = client }
    private func authenticated(_ owner: UUID) async throws -> SupabaseClient {
        guard let client, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }; return client
    }
    func load(owner: UUID) async throws -> ContentFavoritesCache {
        let client = try await authenticated(owner)
        var ids: [String] = [], offset = 0
        while true {
            let rows: [JSONValue] = try await client.from("content_favorites").select("content_id").eq("user_id", value: owner.uuidString).order("content_id").range(from: offset, to: offset + 499).execute().value
            _ = try await authenticated(owner)
            ids += rows.compactMap { $0["content_id"].string }
            if rows.count < 500 { break }; offset += rows.count
        }
        var result = ContentFavoritesCache(owner: owner); result.ids = Array(Set(ids)).sorted()
        for start in stride(from: 0, to: result.ids.count, by: 30) {
            let values: [DailyContent] = try await client.from("daily_contents").select().in("id", values: Array(result.ids[start..<min(start + 30, result.ids.count)])).eq("is_active", value: true).execute().value
            result.contents += values
            _ = try await authenticated(owner)
        }
        return result
    }
    func set(owner: UUID, change: ContentFavoriteChange) async throws {
        guard UUID(uuidString: change.contentID) != nil else { throw URLError(.badURL) }
        let client = try await authenticated(owner)
        if change.enabled {
            try await client.from("content_favorites").upsert(["user_id": owner.uuidString, "content_id": change.contentID], onConflict: "user_id,content_id", ignoreDuplicates: true).execute()
        } else {
            try await client.from("content_favorites").delete().eq("user_id", value: owner.uuidString).eq("content_id", value: change.contentID).execute()
        }
        let confirmed: [JSONValue] = try await client.from("content_favorites").select("content_id").eq("user_id", value: owner.uuidString).eq("content_id", value: change.contentID).execute().value
        guard (!confirmed.isEmpty) == change.enabled else { throw URLError(.cannotParseResponse) }
        _ = try await authenticated(owner)
    }
}

@MainActor final class ContentFavoritesLibrary: ObservableObject {
    @Published private(set) var cache: ContentFavoritesCache?
    @Published private(set) var message: String?
    private let remote: ContentFavoritesRemote
    private let directory: URL
    private var generation = UUID()
    private var inFlight: Set<UUID> = []
    init(remote: ContentFavoritesRemote, directory: URL? = nil) {
        self.remote = remote
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/ContentFavorites")
    }
    private func file(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased() + ".json") }
    private func persist(_ value: ContentFavoritesCache) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file(value.owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache = value
    }
    func select(_ owner: UUID?) {
        guard cache?.owner != owner else { return }
        generation = UUID(); message = nil; cache = owner.map { ContentFavoritesCache(owner: $0) }
        if let owner, let data = try? Data(contentsOf: file(owner)), let value = try? JSONDecoder().decode(ContentFavoritesCache.self, from: data), value.owner == owner { cache = value }
    }
    func contains(_ id: String) -> Bool { cache?.ids.contains(id) == true }
    func toggle(_ content: DailyContent) {
        guard var value = cache, UUID(uuidString: content.id) != nil else { return }
        let enabled = !value.ids.contains(content.id)
        value.ids.removeAll { $0 == content.id }
        if enabled { value.ids.append(content.id); value.contents.removeAll { $0.id == content.id }; value.contents.append(content) }
        else { value.contents.removeAll { $0.id == content.id } }
        value.pending.removeAll { $0.contentID == content.id }; value.pending.append(ContentFavoriteChange(contentID: content.id, enabled: enabled))
        do { try persist(value); message = nil } catch { message = "Le favori n’a pas pu être enregistré sur cet iPhone." }
    }
    func synchronize() async {
        guard let owner = cache?.owner, !inFlight.contains(owner) else { return }
        let token = generation; inFlight.insert(owner); defer { inFlight.remove(owner) }
        do {
            while true {
            while generation == token, let change = cache?.pending.first {
                try await remote.set(owner: owner, change: change)
                guard token == generation, var current = cache else { return }
                current.pending.removeAll { $0.id == change.id }; try persist(current)
            }
            guard token == generation else { return }
            let incoming = try await remote.load(owner: owner)
            guard token == generation, incoming.owner == owner, let current = cache else { return }
            var merged = incoming; merged.pending = current.pending
            for change in current.pending {
                merged.ids.removeAll { $0 == change.contentID }
                merged.contents.removeAll { $0.id == change.contentID }
                if change.enabled {
                    merged.ids.append(change.contentID)
                    if let content = current.contents.first(where: { $0.id == change.contentID }) { merged.contents.append(content) }
                }
            }
            try persist(merged); message = nil
            if merged.pending.isEmpty { return }
            }
        } catch { if token == generation { message = "Tes favoris restent sur cet iPhone. Synchronisation à la reconnexion." } }
    }
}
