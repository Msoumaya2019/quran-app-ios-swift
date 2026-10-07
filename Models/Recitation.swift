import Foundation

struct RecitationFeedback: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let recitation_id: String
    let verse_id: Int?
    let comment: String?
    let voice_path: String?
    let created_at: String
    let resolved_at: String?
    static func combining(general: [Self], verses: [Self]) -> [Self] {
        // The existing RPC also creates an empty general row for a verse's voice attachment.
        // Keep substantive general feedback, but display the same attachment only on its verse.
        let result = general.filter { review in
            guard review.comment?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false, let path = review.voice_path else { return true }
            return !verses.contains { $0.recitation_id == review.recitation_id && $0.voice_path == path }
        } + verses
        return result.sorted { $0.created_at > $1.created_at }
    }
    func belongs(to item: Recitation) -> Bool {
        item.valid && recitation_id == item.id && UUID(uuidString: id) != nil && (verse_id == nil || (item.invocation == nil && (item.start...item.end).contains(verse_id!)))
    }
    static func safeVoicePath(_ path: String) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.count == 3 && parts[0] == "feedback" && UUID(uuidString: String(parts[1])) != nil && Recitation.safeFilename(String(parts[2]))
    }
}

struct Recitation: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let userID: UUID
    let start: Int
    let end: Int
    let durationMs: Int
    let createdAt: String
    let storagePath: String
    var localFile: String?
    var synced: Bool
    var invocation: DailyContent? = nil
    static func validInvocation(_ content: DailyContent) -> Bool { content.type == "invocation" && UUID(uuidString: content.id) != nil && !content.french_text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !content.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var valid: Bool { if let invocation { return start == 0 && end == 0 && Self.validInvocation(invocation) }; return Self.validRange(start, end) }
    static func validRange(_ start: Int, _ end: Int) -> Bool { (1...6236).contains(start) && (start...6236).contains(end) }
    static func safeFilename(_ value: String) -> Bool {
        !value.isEmpty && value.count < 150 && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0) } && !value.contains("..")
    }
}

struct RecitationRow: Codable, Sendable {
    let id: String
    let user_id: UUID
    let start_verse_id: Int?
    let end_verse_id: Int?
    let duration_ms: Int
    let storage_path: String
    let created_at: String
    var recording_type: String = "quran"
    var invocation_id: String? = nil
    var invocation_snapshot: DailyContent? = nil
    init(_ item: Recitation) {
        id = item.id; user_id = item.userID; start_verse_id = item.invocation == nil ? item.start : nil; end_verse_id = item.invocation == nil ? item.end : nil
        recording_type = item.invocation == nil ? "quran" : "invocation"; invocation_id = item.invocation?.id; invocation_snapshot = item.invocation
        duration_ms = item.durationMs; storage_path = item.storagePath; created_at = item.createdAt
    }
    var entry: Recitation { Recitation(id: id, userID: user_id, start: start_verse_id ?? 0, end: end_verse_id ?? 0, durationMs: duration_ms, createdAt: created_at, storagePath: storage_path, synced: true, invocation: recording_type == "invocation" ? invocation_snapshot : nil) }
}
