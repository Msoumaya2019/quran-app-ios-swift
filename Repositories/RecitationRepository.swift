import Foundation
import Supabase

@MainActor protocol RecitationRemote {
    func upload(_ item: Recitation, file: URL) async throws
    func list(owner: UUID) async throws -> [Recitation]
    func download(_ item: Recitation) async throws -> Data
    func reviews(_ item: Recitation) async throws -> [RecitationFeedback]
    func feedbackAudio(_ item: Recitation, review: RecitationFeedback) async throws -> Data
}
extension RecitationRemote {
    func reviews(_ item: Recitation) async throws -> [RecitationFeedback] { [] }
    func feedbackAudio(_ item: Recitation, review: RecitationFeedback) async throws -> Data { throw URLError(.notConnectedToInternet) }
}
@MainActor final class RecitationRepository: RecitationRemote {
    private let client: SupabaseClient?
    init(client: SupabaseClient?) { self.client = client }
    private func authenticated(_ owner: UUID) async throws -> SupabaseClient {
        guard let client, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        return client
    }
    func upload(_ item: Recitation, file: URL) async throws {
        let client = try await authenticated(item.userID)
        guard item.storagePath.hasPrefix(item.userID.uuidString.lowercased() + "/"), item.valid else { throw URLError(.badURL) }
        let bucket = client.storage.from("recitations")
        do { try await bucket.upload(item.storagePath, fileURL: file, options: FileOptions(contentType: "audio/mp4", upsert: false)) }
        catch {
            // A retry after upload success but metadata failure reuses the same object.
            guard try await bucket.exists(path: item.storagePath) else { throw error }
        }
        _ = try await authenticated(item.userID)
        // The invocation trigger resolves its snapshot at INSERT. A retry must not run
        // that trigger again if the already saved content has since been deactivated.
        let fields = "id,user_id,start_verse_id,end_verse_id,duration_ms,storage_path,created_at,recording_type,invocation_id,invocation_snapshot"
        let existing: [RecitationRow] = try await client.from("recitations").select(fields).eq("id", value: item.id).eq("user_id", value: item.userID.uuidString).execute().value
        if existing.isEmpty { try await client.from("recitations").upsert(RecitationRow(item), onConflict: "id", ignoreDuplicates: true).execute() }
        let confirmed: RecitationRow = try await client.from("recitations").select(fields).eq("id", value: item.id).eq("user_id", value: item.userID.uuidString).single().execute().value
        guard confirmed.user_id == item.userID, confirmed.storage_path == item.storagePath, confirmed.duration_ms == item.durationMs,
              confirmed.entry.valid, confirmed.recording_type == (item.invocation == nil ? "quran" : "invocation"),
              item.invocation != nil || (confirmed.start_verse_id == item.start && confirmed.end_verse_id == item.end) else { throw URLError(.cannotParseResponse) }
        if let invocation = item.invocation { guard confirmed.invocation_snapshot?.id == invocation.id else { throw URLError(.cannotParseResponse) } }
        _ = try await authenticated(item.userID)
    }
    func list(owner: UUID) async throws -> [Recitation] {
        let client = try await authenticated(owner)
        let rows: [RecitationRow] = try await client.from("recitations").select("id,user_id,start_verse_id,end_verse_id,duration_ms,storage_path,created_at,recording_type,invocation_id,invocation_snapshot")
            .eq("user_id", value: owner.uuidString).order("created_at", ascending: false).limit(100).execute().value
        return rows.filter { $0.user_id == owner && ["quran", "invocation"].contains($0.recording_type) }.map(\.entry).filter(\.valid)
    }
    func download(_ item: Recitation) async throws -> Data {
        let client = try await authenticated(item.userID)
        guard item.storagePath.hasPrefix(item.userID.uuidString.lowercased() + "/"), !item.storagePath.contains("..") else { throw URLError(.badURL) }
        return try await client.storage.from("recitations").download(path: item.storagePath)
    }
    private func owned(_ item: Recitation) async throws -> SupabaseClient {
        let client = try await authenticated(item.userID)
        let row: JSONValue = try await client.from("recitations").select("id,user_id").eq("id", value: item.id).eq("user_id", value: item.userID.uuidString).single().execute().value
        guard row["id"].string == item.id, row["user_id"].string?.lowercased() == item.userID.uuidString.lowercased() else { throw URLError(.userAuthenticationRequired) }
        return client
    }
    func reviews(_ item: Recitation) async throws -> [RecitationFeedback] {
        let client = try await owned(item)
        async let general: [RecitationFeedback] = client.from("recitation_feedback").select("id,recitation_id,comment,voice_path,created_at").eq("recitation_id", value: item.id).order("created_at", ascending: false).execute().value
        async let corrections: [RecitationFeedback] = client.from("recitation_corrections").select("id,recitation_id,verse_id,comment,voice_path,created_at,resolved_at").eq("recitation_id", value: item.id).order("created_at", ascending: false).execute().value
        let (feedback, marks) = try await (general, corrections)
        let rows = feedback + marks
        guard rows.allSatisfy({ $0.belongs(to: item) }) else { throw URLError(.cannotParseResponse) }
        return RecitationFeedback.combining(general: feedback, verses: marks)
    }
    func feedbackAudio(_ item: Recitation, review: RecitationFeedback) async throws -> Data {
        guard review.belongs(to: item), let path = review.voice_path, RecitationFeedback.safeVoicePath(path) else { throw URLError(.badURL) }
        let client = try await owned(item)
        let table = review.verse_id == nil ? "recitation_feedback" : "recitation_corrections"
        let confirmed: RecitationFeedback = try await client.from(table).select().eq("id", value: review.id).eq("recitation_id", value: item.id).single().execute().value
        guard confirmed.voice_path == path, confirmed.belongs(to: item) else { throw URLError(.badURL) }
        let data = try await client.storage.from("recitations").download(path: path)
        _ = try await authenticated(item.userID)
        guard !data.isEmpty, data.count <= 52_428_800 else { throw URLError(.cannotDecodeContentData) }
        return data
    }
}
