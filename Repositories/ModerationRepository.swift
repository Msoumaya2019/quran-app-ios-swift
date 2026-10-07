import Foundation
import Supabase

enum ModerationSection: String, CaseIterable { case recitations, messages, reports, members }
@MainActor protocol ModerationRemote {
    func suspension(owner: UUID, user: UUID, reason: String?, until: Date?) async throws -> JSONValue
    func rows(owner: UUID, section: ModerationSection, offset: Int) async throws -> [JSONValue]
    func profiles(owner: UUID, ids: [String]) async throws -> [JSONValue]
    func recording(owner: UUID, id: String) async throws -> JSONValue
    func audio(owner: UUID, row: JSONValue) async throws -> Data
    func deleteMessage(owner: UUID, id: String) async throws -> JSONValue
    func resolveReport(owner: UUID, id: String) async throws -> JSONValue
    func listened(owner: UUID, id: String) async throws -> JSONValue
    func feedback(owner: UUID, recitation: String, id: UUID, comment: String) async throws
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws
    func verseFeedback(owner: UUID, recitation: String, id: UUID, verseID: Int, comment: String, data: Data?) async throws
}

extension ModerationRemote {
    func suspension(owner: UUID, user: UUID, reason: String?, until: Date?) async throws -> JSONValue { throw URLError(.unsupportedURL) }
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws { throw URLError(.unsupportedURL) }
    func verseFeedback(owner: UUID, recitation: String, id: UUID, verseID: Int, comment: String, data: Data?) async throws { throw URLError(.unsupportedURL) }
}

@MainActor final class ModerationRepository: ModerationRemote {
    private let client: SupabaseClient?
    init(client: SupabaseClient?) { self.client = client }
    private func authorized(_ owner: UUID) async throws -> SupabaseClient {
        guard let client, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        let admins: [JSONValue] = try await client.from("app_admins").select("user_id").eq("user_id", value: owner.uuidString).limit(1).execute().value
        guard admins.contains(where: { $0["user_id"].string?.lowercased() == owner.uuidString.lowercased() }),
              try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        return client
    }
    func rows(owner: UUID, section: ModerationSection, offset: Int) async throws -> [JSONValue] {
        let client = try await authorized(owner)
        if section == .members {
            let profiles: [JSONValue] = try await client.from("friend_profiles").select("id,display_name,created_at").order("created_at", ascending: false).order("id", ascending: false).range(from: offset, to: offset + 49).execute().value
            let ids = profiles.compactMap { $0["id"].string }
            guard !ids.isEmpty else { return [] }
            let suspended: [JSONValue] = try await client.from("social_suspensions").select().in("user_id", values: ids).execute().value
            let admins: [JSONValue] = try await client.from("app_admins").select("user_id").in("user_id", values: ids).execute().value
            _ = try await authorized(owner)
            return profiles.map { row in
                row.setting("suspension", suspended.first { $0["user_id"] == row["id"] } ?? .null)
                    .setting("protected", .bool(admins.contains { $0["user_id"] == row["id"] } || row["id"].string?.lowercased() == owner.uuidString.lowercased()))
            }
        }
        let table = section == .recitations ? "recitations" : section == .messages ? "friend_messages" : "friend_message_reports"
        return try await client.from(table).select().order("created_at", ascending: false).order("id", ascending: false).range(from: offset, to: offset + 49).execute().value
    }
    func suspension(owner: UUID, user: UUID, reason: String?, until: Date?) async throws -> JSONValue {
        let client = try await authorized(owner)
        guard user != owner else { throw URLError(.noPermissionsToReadFile) }
        if let reason {
            let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard (2...500).contains(text.count), until == nil || until! > Date() else { throw URLError(.badURL) }
            struct Args: Encodable { let p_user: UUID; let p_reason: String; let p_until: String? }
            try await client.rpc("suspend_social_member", params: Args(p_user: user, p_reason: text, p_until: until.map { ISO8601DateFormatter().string(from: $0) })).execute()
        } else {
            try await client.rpc("unsuspend_social_member", params: ["p_user": user.uuidString]).execute()
        }
        _ = try await authorized(owner)
        let rows: [JSONValue] = try await client.from("social_suspensions").select().eq("user_id", value: user.uuidString).limit(1).execute().value
        guard reason == nil ? rows.isEmpty : rows.first?["reason"].string == reason?.trimmingCharacters(in: .whitespacesAndNewlines) else { throw URLError(.cannotParseResponse) }
        _ = try await authorized(owner)
        return rows.first ?? .null
    }
    func profiles(owner: UUID, ids: [String]) async throws -> [JSONValue] {
        let client = try await authorized(owner)
        guard !ids.isEmpty else { return [] }
        return try await client.from("friend_profiles").select("id,display_name").in("id", values: Array(Set(ids))).execute().value
    }
    static func validAudioPath(_ row: JSONValue) -> Bool {
        guard let user = row["user_id"].string.flatMap(UUID.init(uuidString:)), let path = row["storage_path"].string,
              path.hasPrefix(user.uuidString.lowercased() + "/"), !path.contains(".."), !path.contains("\\"), !path.contains("%"), !path.hasSuffix("/") else { return false }
        return true
    }
    func recording(owner: UUID, id: String) async throws -> JSONValue {
        let client = try await authorized(owner)
        return try await client.from("recitations").select().eq("id", value: id).single().execute().value
    }
    func audio(owner: UUID, row: JSONValue) async throws -> Data {
        let client = try await authorized(owner)
        guard Self.validAudioPath(row), let id = row["id"].string else { throw URLError(.badURL) }
        let current: JSONValue = try await client.from("recitations").select().eq("id", value: id).single().execute().value
        guard current["user_id"] == row["user_id"], current["storage_path"] == row["storage_path"] else { throw URLError(.badURL) }
        let data = try await client.storage.from("recitations").download(path: row["storage_path"].string!)
        _ = try await authorized(owner)
        guard !data.isEmpty, data.count <= 52_428_800 else { throw URLError(.cannotDecodeContentData) }
        return data
    }
    func deleteMessage(owner: UUID, id: String) async throws -> JSONValue {
        let client = try await authorized(owner)
        _ = try await client.rpc("delete_friend_message", params: ["p_message": id]).execute()
        let row: JSONValue = try await client.from("friend_messages").select().eq("id", value: id).single().execute().value
        guard row["id"].string?.lowercased() == id.lowercased(), row["deleted_at"] != .null else { throw URLError(.cannotParseResponse) }
        return row
    }
    func resolveReport(owner: UUID, id: String) async throws -> JSONValue {
        let client = try await authorized(owner)
        _ = try await client.rpc("resolve_friend_report", params: ["p_report": id]).execute()
        let row: JSONValue = try await client.from("friend_message_reports").select().eq("id", value: id).single().execute().value
        guard row["id"].string?.lowercased() == id.lowercased(), row["status"].string == "reviewed" else { throw URLError(.cannotParseResponse) }
        return row
    }
    func listened(owner: UUID, id: String) async throws -> JSONValue {
        let client = try await authorized(owner)
        _ = try await client.from("recitations").update(["listened_at": ISO8601DateFormatter().string(from: .now)]).eq("id", value: id).is("listened_at", value: nil).execute()
        let row: JSONValue = try await client.from("recitations").select().eq("id", value: id).single().execute().value
        guard row["id"].string == id, row["listened_at"] != .null else { throw URLError(.cannotParseResponse) }
        return row
    }
    func feedback(owner: UUID, recitation: String, id: UUID, comment: String) async throws {
        let client = try await authorized(owner)
        struct Values: Encodable { let id: UUID; let recitation_id: String; let admin_id: UUID; let comment: String }
        let value = Values(id: id, recitation_id: recitation, admin_id: owner, comment: comment)
        try await client.from("recitation_feedback").upsert(value, onConflict: "id", ignoreDuplicates: true).execute()
        let confirmed: JSONValue = try await client.from("recitation_feedback").select().eq("id", value: id.uuidString).single().execute().value
        guard confirmed["admin_id"].string?.lowercased() == owner.uuidString.lowercased(), confirmed["recitation_id"].string == recitation, confirmed["comment"].string == comment else { throw URLError(.cannotParseResponse) }
    }
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws {
        try await publishCorrection(owner: owner, recitation: recitation, id: id, verseID: nil, comment: comment, data: data)
    }
    static func validVerse(_ verseID: Int, in row: JSONValue) -> Bool {
        guard row["recording_type"].string != "invocation", let start = row["start_verse_id"].int, let end = row["end_verse_id"].int,
              Recitation.validRange(start, end) else { return false }
        return (start...end).contains(verseID)
    }
    func verseFeedback(owner: UUID, recitation: String, id: UUID, verseID: Int, comment: String, data: Data?) async throws {
        try await publishCorrection(owner: owner, recitation: recitation, id: id, verseID: verseID, comment: comment, data: data)
    }
    private func publishCorrection(owner: UUID, recitation: String, id: UUID, verseID: Int?, comment: String, data: Data?) async throws {
        let client = try await authorized(owner)
        guard comment.count <= 2000, !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || data != nil else { throw URLError(.cannotDecodeContentData) }
        if let verseID {
            let row: JSONValue = try await client.from("recitations").select("recording_type,start_verse_id,end_verse_id").eq("id", value: recitation).single().execute().value
            guard Self.validVerse(verseID, in: row) else { throw URLError(.badURL) }
            _ = try await authorized(owner)
        }
        var path: String?
        // Existing storage policies permit insert/read, not overwrite. Retry verifies the same object.
        if let data {
            guard !data.isEmpty, data.count <= 52_428_800 else { throw URLError(.cannotDecodeContentData) }
            let filePath = "feedback/\(owner.uuidString.lowercased())/\(id.uuidString.lowercased()).m4a"
            let bucket = client.storage.from("recitations")
            do { try await bucket.upload(filePath, data: data, options: FileOptions(contentType: "audio/mp4", upsert: false)) }
            catch {
                let existing = try await bucket.download(path: filePath)
                guard existing == data else { throw error }
            }
            path = filePath
        }
        _ = try await authorized(owner)
        struct Verse: Encodable { let verseId: Int; let comment: String }
        struct Parameters: Encodable {
            let p_recitation_id: String
            let p_request_id: String
            let p_verses: [Verse]
            let p_general_comment: String
            let p_voice_path: String?
            // Supabase requires this nullable argument even for a written-only correction.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(p_recitation_id, forKey: .p_recitation_id); try c.encode(p_request_id, forKey: .p_request_id)
                try c.encode(p_verses, forKey: .p_verses); try c.encode(p_general_comment, forKey: .p_general_comment)
                try c.encode(p_voice_path, forKey: .p_voice_path)
            }
            enum CodingKeys: String, CodingKey { case p_recitation_id, p_request_id, p_verses, p_general_comment, p_voice_path }
        }
        _ = try await client.rpc("finalize_recitation_correction", params: Parameters(p_recitation_id: recitation, p_request_id: id.uuidString.lowercased(), p_verses: verseID.map { [Verse(verseId: $0, comment: comment)] } ?? [], p_general_comment: verseID == nil ? comment : "", p_voice_path: path)).execute()
        _ = try await authorized(owner)
        let confirmed: JSONValue = try await client.from("recitations").select("id,last_correction_request_id").eq("id", value: recitation).single().execute().value
        guard confirmed["last_correction_request_id"].string == id.uuidString.lowercased() else { throw URLError(.cannotParseResponse) }
    }
}
