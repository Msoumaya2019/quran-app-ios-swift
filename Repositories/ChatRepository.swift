import Foundation
import Supabase

struct ChatPage { let messages: [ChatMessage]; let hidden: Set<UUID> }
@MainActor protocol ChatRemote {
    func startUpdates(owner: UUID, link: UUID, onChange: @escaping @MainActor @Sendable () -> Void) async
    func stopUpdates()
    func load(owner: UUID, link: UUID, before: ChatMessage?) async throws -> ChatPage
    func send(owner: UUID, message: ChatMessage) async throws -> ChatMessage
    func markRead(owner: UUID, link: UUID, through: String) async throws
}
extension ChatRemote {
    func startUpdates(owner: UUID, link: UUID, onChange: @escaping @MainActor @Sendable () -> Void) async {}
    func stopUpdates() {}
}
@MainActor final class ChatRepository: ChatRemote {
    let client: SupabaseClient?
    private let group: Bool
    private var channel: RealtimeChannelV2?
    private var subscription: RealtimeSubscription?
    private var updateGeneration = UUID()
    func stopUpdates() {
        updateGeneration = UUID()
        subscription?.cancel(); subscription = nil
        if let old = channel, let client { Task { await client.removeChannel(old) } }
        channel = nil
    }
    func startUpdates(owner: UUID, link: UUID, onChange: @escaping @MainActor @Sendable () -> Void) async {
        stopUpdates()
        let token = updateGeneration
        do {
            let client = try await authorized(owner)
            guard token == updateGeneration, !Task.isCancelled else { return }
            let next = client.channel("native-chat-" + UUID().uuidString)
            channel = next
            subscription = next.onPostgresChange(AnyAction.self, schema: "public", table: "friend_messages",
                filter: "\(group ? "group_id" : "link_id")=eq.\(link.uuidString.lowercased())") { [weak self] _ in
                Task { @MainActor in
                    guard let self, token == self.updateGeneration else { return }
                    onChange()
                }
            }
            try await next.subscribeWithError()
            guard token == updateGeneration, !Task.isCancelled else { return }
            onChange() // Recover anything committed between the initial fetch and subscription.
        } catch {
            // Periodic refresh remains available if Realtime is not enabled on this backend.
            if token == updateGeneration { stopUpdates() }
        }
    }
    init(client: SupabaseClient?, group: Bool = false) { self.client = client; self.group = group }
    private func authorized(_ owner: UUID) async throws -> SupabaseClient {
        guard let client, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }; return client
    }
    func load(owner: UUID, link: UUID, before: ChatMessage?) async throws -> ChatPage {
        let client = try await authorized(owner)
        var query = client.from("friend_messages").select().eq(group ? "group_id" : "link_id", value: link.uuidString)
        if let before, ChatMessage.date(before.createdAt) != nil {
            query = query.or("created_at.lt.\(before.createdAt),and(created_at.eq.\(before.createdAt),id.lt.\(before.id.uuidString))")
        }
        let messages: [ChatMessage] = try await query.order("created_at", ascending: false).order("id", ascending: false).limit(50).execute().value
        struct Hidden: Decodable { let message_id: UUID }
        let hidden: [Hidden] = messages.isEmpty ? [] : try await client.from("friend_message_hidden").select("message_id").in("message_id", values: messages.map { $0.id.uuidString }).execute().value
        return ChatPage(messages: messages, hidden: Set(hidden.map(\.message_id)))
    }
    func send(owner: UUID, message: ChatMessage) async throws -> ChatMessage {
        let client = try await authorized(owner)
        guard message.senderID == owner, (group ? message.groupID != nil && message.linkID == nil : message.linkID != nil && message.groupID == nil) else { throw ChatError.mismatch }
        let existing: [ChatMessage] = try await client.from("friend_messages").select().eq("id", value: message.id.uuidString).limit(1).execute().value
        if let row = existing.first { guard row.acknowledges(message) else { throw ChatError.mismatch }; return row }
        struct Insert: Encodable { let id: UUID; let link_id: UUID?; let group_id: UUID?; let sender_id: UUID; let body: String; let kind: String }
        let rows: [ChatMessage] = try await client.from("friend_messages").insert(Insert(id: message.id, link_id: message.linkID, group_id: message.groupID, sender_id: owner, body: message.body, kind: message.kind)).select().execute().value
        guard let row = rows.first, row.acknowledges(message) else { throw ChatError.mismatch }; return row
    }
    func markRead(owner: UUID, link: UUID, through: String) async throws {
        guard !group else { return }
        let client = try await authorized(owner)
        struct Read: Codable { let link_id: UUID; let user_id: UUID; let last_read_at: String }
        let rows: [Read] = try await client.from("friend_message_reads").select().eq("link_id", value: link.uuidString).eq("user_id", value: owner.uuidString).limit(1).execute().value
        guard let date = ChatMessage.date(through), rows.first.flatMap({ ChatMessage.date($0.last_read_at) }).map({ $0 < date }) != false else { return }
        try await client.from("friend_message_reads").upsert(Read(link_id: link, user_id: owner, last_read_at: through)).execute()
    }
}
