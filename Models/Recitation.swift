import Foundation

struct RecitationFeedback: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let recitation_id: String
    let verse_id: Int?
    let comment: String?
    let voice_path: String?
    let created_at: String
    let resolved_at: String?
    func belongs(to item: Recitation) -> Bool {
        Recitation.validRange(item.start, item.end) && recitation_id == item.id && UUID(uuidString: id) != nil && (verse_id == nil || (item.start...item.end).contains(verse_id!))
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
    static func validRange(_ start: Int, _ end: Int) -> Bool { (1...6236).contains(start) && (start...6236).contains(end) }
    static func safeFilename(_ value: String) -> Bool {
        !value.isEmpty && value.count < 150 && value.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.").contains($0) } && !value.contains("..")
    }
}

struct RecitationRow: Codable, Sendable {
    let id: String
    let user_id: UUID
    let start_verse_id: Int
    let end_verse_id: Int
    let duration_ms: Int
    let storage_path: String
    let created_at: String
    var recording_type: String = "quran"
    init(_ item: Recitation) {
        id = item.id; user_id = item.userID; start_verse_id = item.start; end_verse_id = item.end
        duration_ms = item.durationMs; storage_path = item.storagePath; created_at = item.createdAt
    }
    var entry: Recitation { Recitation(id: id, userID: user_id, start: start_verse_id, end: end_verse_id, durationMs: duration_ms, createdAt: created_at, storagePath: storage_path, synced: true) }
}
