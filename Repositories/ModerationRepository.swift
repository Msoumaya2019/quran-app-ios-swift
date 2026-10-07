import Foundation
import Supabase

enum ModerationSection: String, CaseIterable { case recitations, messages, reports }
@MainActor protocol ModerationRemote {
    func rows(owner: UUID, section: ModerationSection, offset: Int) async throws -> [JSONValue]
    func profiles(owner: UUID, ids: [String]) async throws -> [JSONValue]
    func recording(owner: UUID, id: String) async throws -> JSONValue
    func audio(owner: UUID, row: JSONValue) async throws -> Data
    func deleteMessage(owner: UUID, id: String) async throws -> JSONValue
    func resolveReport(owner: UUID, id: String) async throws -> JSONValue
    func listened(owner: UUID, id: String) async throws -> JSONValue
    func feedback(owner: UUID, recitation: String, id: UUID, comment: String) async throws
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws
}

extension ModerationRemote {
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws { throw URLError(.unsupportedURL) }
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
        let table = section == .recitations ? "recitations" : section == .messages ? "friend_messages" : "friend_message_reports"
        return try await client.from(table).select().order("created_at", ascending: false).order("id", ascending: false).range(from: offset, to: offset + 49).execute().value
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
        let client = try await authorized(owner)
        guard !data.isEmpty, data.count <= 52_428_800, comment.count <= 2000 else { throw URLError(.cannotDecodeContentData) }
        let path = "feedback/\(owner.uuidString.lowercased())/\(id.uuidString.lowercased()).m4a"
        // Existing storage policies permit insert/read, not overwrite. Retry verifies the same object.
        let bucket = client.storage.from("recitations")
        do { try await bucket.upload(path, data: data, options: FileOptions(contentType: "audio/mp4", upsert: false)) }
        catch {
            let existing = try await bucket.download(path: path)
            guard existing == data else { throw error }
        }
        _ = try await authorized(owner)
        struct Parameters: Encodable {
            let p_recitation_id: String
            let p_request_id: String
            let p_verses: [Int]
            let p_general_comment: String
            let p_voice_path: String
        }
        _ = try await client.rpc("finalize_recitation_correction", params: Parameters(p_recitation_id: recitation, p_request_id: id.uuidString.lowercased(), p_verses: [], p_general_comment: comment, p_voice_path: path)).execute()
        _ = try await authorized(owner)
        let confirmed: JSONValue = try await client.from("recitations").select("id,last_correction_request_id").eq("id", value: recitation).single().execute().value
        guard confirmed["last_correction_request_id"].string == id.uuidString.lowercased() else { throw URLError(.cannotParseResponse) }
    }
}
