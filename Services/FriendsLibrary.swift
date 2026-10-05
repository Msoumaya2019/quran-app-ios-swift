import Foundation
import Supabase

@MainActor final class FriendsLibrary: ObservableObject {
    @Published private(set) var snapshot: FriendsSnapshot?
    @Published private(set) var loading = false
    @Published private(set) var message: String?
    @Published private(set) var groups: [JSONValue] = []
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
        groups = []
        if let user, let data = try? Data(contentsOf: groupFile(user)), let values = try? JSONDecoder().decode([JSONValue].self, from: data) { groups = values }
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
    private func groupFile(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased() + "-groups.json") }
    func refreshGroups() async {
        guard let owner = snapshot?.owner, let client else { return }; let token = generation
        do {
            guard try await client.auth.session.user.id == owner else { return }
            let values: [JSONValue] = try await client.from("friend_groups").select().order("created_at", ascending: false).execute().value
            guard token == generation else { return }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(values).write(to: groupFile(owner), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); groups = values
        } catch { if token == generation { message = "Groupes indisponibles. Les données déjà synchronisées restent accessibles." } }
    }
    func groupMembers(_ id: String) async -> [JSONValue] {
        guard let owner = snapshot?.owner, UUID(uuidString: id) != nil else { return [] }
        let file = directory.appendingPathComponent(owner.uuidString.lowercased() + "-group-" + id.lowercased() + ".json"), token = generation
        let stored = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([JSONValue].self, from: $0) } ?? []
        guard let client else { return stored }
        do {
            guard try await client.auth.session.user.id == owner else { return [] }
            let members: [JSONValue] = try await client.from("friend_group_members").select().eq("group_id", value: id).execute().value
            let ids = members.compactMap { $0["user_id"].string }
            let profiles: [JSONValue] = ids.isEmpty ? [] : try await client.from("friend_profiles").select("id,display_name").in("id", values: ids).execute().value
            let rows = members.map { member in member.setting("name", profiles.first { $0["id"].string?.lowercased() == member["user_id"].string?.lowercased() }?["display_name"] ?? .string("Membre")) }
            guard token == generation else { return [] }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(rows).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return rows
        } catch { guard token == generation else { return [] }; message = "Membres disponibles hors connexion selon la dernière synchronisation."; return stored }
    }
    func cachedGroupMembers(_ id: String) -> [JSONValue] {
        guard let owner = snapshot?.owner, UUID(uuidString: id) != nil else { return [] }
        let file = directory.appendingPathComponent(owner.uuidString.lowercased() + "-group-" + id.lowercased() + ".json")
        return (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([JSONValue].self, from: $0) } ?? []
    }
    func createGroup(_ name: String) async -> Bool {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, text.count <= 80 else { return false }
        struct Args: Encodable { let p_name: String }
        let result = await action { client in let _: UUID = try await client.rpc("create_friend_group", params: Args(p_name: text)).execute().value }
        if result { await refreshGroups() }; return result
    }
    func groupConversation(_ id: String) -> (owner: UUID, link: UUID, remote: ChatRemote)? {
        guard let owner = snapshot?.owner, let group = UUID(uuidString: id) else { return nil }
        return (owner, group, ChatRepository(client: client, group: true))
    }
    func groupMemberAction(_ actionName: String, group: String, member: String?, enabled: Bool = false) async -> Bool {
        guard UUID(uuidString: group) != nil else { return false }
        struct Args: Encodable { let p_group: String; let p_member: String; let p_enabled: Bool }
        if actionName == "set_group_moderator", let member, UUID(uuidString: member) != nil {
            return await action { client in try await client.rpc(actionName, params: Args(p_group: group, p_member: member, p_enabled: enabled)).execute() }
        }
        guard ["remove_group_member", "delete_friend_group"].contains(actionName) else { return false }
        var args = ["p_group": group]
        if actionName == "remove_group_member" { guard let member, UUID(uuidString: member) != nil else { return false }; args["p_member"] = member }
        return await action { client in try await client.rpc(actionName, params: args).execute() }
    }
    func groupAction(_ name: String, id: String, friend: String?) async -> Bool {
        guard ["accept_group_invite", "decline_group_invite", "invite_group_member"].contains(name), UUID(uuidString: id) != nil else { return false }
        var args: [String: String] = ["p_group": id]
        if name == "invite_group_member" { guard let friend, snapshot?.items().contains(where: { $0.otherID == friend && $0.status == "accepted" }) == true else { return false }; args["p_friend"] = friend }
        let result = await action { client in try await client.rpc(name, params: args).execute() }
        if result { await refreshGroups() }; return result
    }
    struct LinkArgs: Encodable { let p_link: String }
    struct OtherArgs: Encodable { let p_other: String }
    func conversationConfiguration(for item: FriendItem) -> (owner: UUID, link: UUID, remote: ChatRemote)? {
        guard let owner = snapshot?.owner, let link = UUID(uuidString: item.id), snapshot?.items().contains(where: { $0.id == item.id }) == true else { return nil }
        return (owner, link, ChatRepository(client: client))
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
    func saveSocialProfile(name: String, online: Bool, progress: Bool) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...40).contains(trimmed.unicodeScalars.count), let owner = snapshot?.owner else {
            message = "Le nom doit contenir entre 2 et 40 caractères."; return false
        }
        struct Values: Encodable { let display_name: String; let share_online: Bool; let share_progress: Bool }
        // Update only edited fields; preserve avatar, location and future preferences.
        return await action { client in
            _ = try await client.rpc("ensure_social_profile").execute()
            let confirmed: JSONValue = try await client.from("friend_profiles")
                .update(Values(display_name: trimmed, share_online: online, share_progress: progress))
                .eq("id", value: owner.uuidString).select().single().execute().value
            guard confirmed["id"].string?.lowercased() == owner.uuidString.lowercased(),
                  confirmed["display_name"].string == trimmed,
                  confirmed["share_online"].bool == online, confirmed["share_progress"].bool == progress else { throw URLError(.cannotParseResponse) }
        }
    }
    private func action(_ operation: (SupabaseClient) async throws -> Void) async -> Bool {
        guard !actionBusy, let owner = snapshot?.owner, let client else { message = "Connexion nécessaire pour cette action."; return false }
        let token = generation; actionBusy = true; defer { actionBusy = false }
        do {
            guard try await client.auth.session.user.id == owner, token == generation else { return false }
            try await operation(client)
            guard token == generation else { return false }
            await refresh(); return true
        } catch {
            guard token == generation else { return false }
            message = "L’action n’a pas été confirmée. Vérifie ta connexion et réessaie."; return false
        }
    }
}
