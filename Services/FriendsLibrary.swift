import Foundation
import Supabase

@MainActor final class FriendsLibrary: ObservableObject {
    @Published private(set) var snapshot: FriendsSnapshot?
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    private let client: SupabaseClient?
    private var generation = UUID()
    private var actionBusy = false
    private let directory: URL
    init(client: SupabaseClient?, directory: URL? = nil) {
        self.client = client
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Friends")
    }
    private func file(_ user: UUID) -> URL { directory.appendingPathComponent(user.uuidString.lowercased() + ".json") }
    func select(_ user: UUID?) {
        guard snapshot?.owner != user else { return }
        generation = UUID(); loading = false; message = nil; snapshot = user.map { FriendsSnapshot(owner: $0) }
        if let user, let data = try? Data(contentsOf: file(user)), let cache = try? JSONDecoder().decode(FriendsSnapshot.self, from: data), cache.owner == user { snapshot = cache }
    }
    func refresh() async {
        guard !loading, let previous = snapshot, let client else { return }
        let token = generation; loading = true
        defer { if token == generation { loading = false } }
        do {
            async let profile: JSONValue = client.rpc("ensure_social_profile").execute().value
            async let links: JSONValue = client.from("friend_links").select("id,requester_id,recipient_id,status,blocked_by,created_at").order("created_at", ascending: false).execute().value
            async let inbox: JSONValue = client.rpc("friend_inbox").execute().value
            var next = previous; next.profile = try await profile; next.links = try await links
            let user = previous.owner.uuidString.lowercased()
            let ids = Set(next.links.array.compactMap { row -> String? in
                let requester = row["requester_id"].string?.lowercased(), recipient = row["recipient_id"].string?.lowercased()
                guard requester == user || recipient == user else { return nil }
                return requester == user ? recipient : requester
            })
            if !ids.isEmpty { next.profiles = try await client.from("friend_profiles").select("id,display_name,avatar_path,share_online,share_progress").in("id", values: Array(ids)).execute().value }
            else { next.profiles = .array([]) }
            // Presence is optional on older backends. Never reuse stale online indicators.
            next.inbox = (try? await inbox) ?? .array([])
            guard token == generation else { return }
            let accepted = Set(next.items().map(\.otherID))
            next.overviews = snapshot?.overviews?.filter { entry in
                accepted.contains(entry.key) && next.profiles.array.contains { row in row["id"].string?.lowercased() == entry.key && row["share_progress"].bool == true }
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file(next.owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            snapshot = next; message = nil
        } catch {
            guard token == generation else { return }
            message = "Actualisation indisponible. Les amis déjà synchronisés restent accessibles."
        }
    }
    struct CodeArgs: Encodable { let p_code: String }
    struct LinkArgs: Encodable { let p_link: String }
    struct OtherArgs: Encodable { let p_other: String }
    func conversation(for item: FriendItem) -> ConversationLibrary? {
        guard let owner = snapshot?.owner, let link = UUID(uuidString: item.id), snapshot?.items().contains(where: { $0.id == item.id }) == true else { return nil }
        return ConversationLibrary(owner: owner, link: link, remote: ChatRepository(client: client))
    }
    func refreshOverview(_ id: String) async -> String? {
        guard let client, snapshot?.items().contains(where: { $0.otherID == id }) == true else { return "Profil non disponible en ligne." }
        let token = generation
        do {
            let rows: JSONValue = try await client.rpc("friend_overview", params: OtherArgs(p_other: id)).execute().value
            guard token == generation, var next = snapshot, next.items().contains(where: { $0.otherID == id }) else { return nil }
            guard let row = rows.array.first, row["id"].string?.lowercased() == id else { throw URLError(.cannotParseResponse) }
            var values = next.overviews ?? [:]; values[id] = row; next.overviews = values
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file(next.owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            snapshot = next; return nil
        } catch {
            guard token == generation else { return nil }
            return "Actualisation indisponible. Les informations déjà synchronisées restent affichées."
        }
    }
    func request(code: String) async -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return await action { client in _ = try await client.rpc("request_friend", params: CodeArgs(p_code: trimmed)).execute() }
    }
    func respond(_ item: FriendItem, accept: Bool) async -> Bool {
        guard item.incoming, item.status == "pending" else { return false }
        return await action { client in _ = try await client.rpc(accept ? "accept_friend" : "decline_friend", params: LinkArgs(p_link: item.id)).execute() }
    }
    private func action(_ operation: (SupabaseClient) async throws -> Void) async -> Bool {
        guard !actionBusy, snapshot != nil, let client else { message = "Connexion nécessaire pour cette action."; return false }
        let token = generation; actionBusy = true; defer { actionBusy = false }
        do {
            try await operation(client)
            guard token == generation else { return false }
            await refresh(); return true
        } catch {
            guard token == generation else { return false }
            message = "L’action n’a pas été confirmée. Vérifie ta connexion et réessaie."; return false
        }
    }
}
