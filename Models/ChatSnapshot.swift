import Foundation

struct ChatMessage: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let linkID: UUID?
    let groupID: UUID?
    let senderID: UUID
    let kind: String
    let body: String
    let createdAt: String
    let deletedAt: String?
    let recitationID: UUID?
    enum CodingKeys: String, CodingKey {
        case id, kind, body
        case linkID = "link_id", groupID = "group_id", senderID = "sender_id", createdAt = "created_at", deletedAt = "deleted_at", recitationID = "recitation_id"
    }
    var displayBody: String { deletedAt == nil ? body : "Message supprimé" }
    var timestamp: Date { Self.date(createdAt) ?? .distantPast }
    static func date(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
    func acknowledges(_ pending: ChatMessage) -> Bool {
        id == pending.id && linkID == pending.linkID && groupID == pending.groupID && senderID == pending.senderID && kind == pending.kind && (body == pending.body || deletedAt != nil)
    }
}
struct ChatSnapshot: Codable, Equatable {
    let owner: UUID
    let linkID: UUID
    var groupRoom: Bool? = nil
    private func belongs(_ row: ChatMessage) -> Bool { groupRoom == true ? row.groupID == linkID && row.linkID == nil : row.linkID == linkID && row.groupID == nil }
    var messages: [ChatMessage] = []
    var pending: [ChatMessage] = []
    var hidden: Set<UUID> = []
    var visible: [ChatMessage] {
        var values = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for message in pending where values[message.id] == nil { values[message.id] = message }
        return values.values.filter { belongs($0) && !hidden.contains($0.id) }.sorted {
            $0.timestamp == $1.timestamp ? $0.id.uuidString < $1.id.uuidString : $0.timestamp < $1.timestamp
        }
    }
    mutating func merge(_ rows: [ChatMessage], hiddenIDs: Set<UUID> = []) {
        let rows = rows.filter { belongs($0) }
        var values = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for row in rows {
            if values[row.id]?.deletedAt != nil && row.deletedAt == nil { continue }
            values[row.id] = row
        }
        messages = Array(values.values)
        hidden.formUnion(hiddenIDs)
        pending.removeAll { pending in rows.contains { $0.acknowledges(pending) } }
    }
    mutating func enqueue(_ body: String, id: UUID = UUID(), now: Date = .now) throws -> ChatMessage {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.unicodeScalars.count <= 2000 else { throw ChatError.invalidBody }
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let message = ChatMessage(id: id, linkID: groupRoom == true ? nil : linkID, groupID: groupRoom == true ? linkID : nil, senderID: owner, kind: "text", body: trimmed, createdAt: formatter.string(from: now), deletedAt: nil, recitationID: nil)
        guard !pending.contains(where: { $0.id == id }), !messages.contains(where: { $0.id == id }) else { throw ChatError.duplicate }
        pending.append(message); return message
    }
}
enum ChatError: LocalizedError {
    case invalidBody, duplicate, mismatch
    var errorDescription: String? {
        switch self { case .invalidBody: return "Écris un message de 1 à 2 000 caractères."; case .duplicate: return "Ce message est déjà enregistré."; case .mismatch: return "Le message reçu ne correspond pas à cet envoi." }
    }
}
struct ChatCache {
    let directory: URL
    init(directory: URL? = nil) { self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Conversations") }
    private func file(owner: UUID, link: UUID, group: Bool = false) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased()).appendingPathComponent((group ? "group-" : "") + link.uuidString.lowercased() + ".json") }
    func load(owner: UUID, link: UUID, group: Bool = false) throws -> ChatSnapshot? {
        let file = file(owner: owner, link: link, group: group)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        let value = try JSONDecoder().decode(ChatSnapshot.self, from: Data(contentsOf: file))
        guard value.owner == owner, value.linkID == link, (value.groupRoom == true) == group else { throw ChatError.mismatch }; return value
    }
    func save(_ value: ChatSnapshot) throws {
        let file = file(owner: value.owner, link: value.linkID, group: value.groupRoom == true)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
