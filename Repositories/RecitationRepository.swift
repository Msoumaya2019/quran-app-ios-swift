import Foundation
import Supabase

@MainActor protocol RecitationRemote {
    func upload(_ item: Recitation, file: URL) async throws
    func list(owner: UUID) async throws -> [Recitation]
    func download(_ item: Recitation) async throws -> Data
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
        guard item.storagePath.hasPrefix(item.userID.uuidString.lowercased() + "/"), Recitation.validRange(item.start, item.end) else { throw URLError(.badURL) }
        let bucket = client.storage.from("recitations")
        do { try await bucket.upload(item.storagePath, fileURL: file, options: FileOptions(contentType: "audio/mp4", upsert: false)) }
        catch {
            // A retry after upload success but metadata failure reuses the same object.
            guard try await bucket.exists(path: item.storagePath) else { throw error }
        }
        _ = try await authenticated(item.userID)
        try await client.from("recitations").upsert(RecitationRow(item), onConflict: "id", ignoreDuplicates: true).execute()
    }
    func list(owner: UUID) async throws -> [Recitation] {
        let client = try await authenticated(owner)
        let rows: [RecitationRow] = try await client.from("recitations").select("id,user_id,start_verse_id,end_verse_id,duration_ms,storage_path,created_at,recording_type")
            .eq("user_id", value: owner.uuidString).eq("recording_type", value: "quran").order("created_at", ascending: false).limit(100).execute().value
        return rows.filter { $0.user_id == owner }.map(\.entry)
    }
    func download(_ item: Recitation) async throws -> Data {
        let client = try await authenticated(item.userID)
        guard item.storagePath.hasPrefix(item.userID.uuidString.lowercased() + "/"), !item.storagePath.contains("..") else { throw URLError(.badURL) }
        return try await client.storage.from("recitations").download(path: item.storagePath)
    }
}
