import Foundation
import Supabase

@MainActor protocol EditorialRemote {
    func load(owner: UUID, kind: EditorialKind, offset: Int) async throws -> EditorialSnapshot
    func save(owner: UUID, draft: EditorialDraft) async throws -> JSONValue
    func saveCategory(owner: UUID, row: JSONValue) async throws -> JSONValue
    func delete(owner: UUID, id: String, category: Bool) async throws
    func unschedule(owner: UUID, row: JSONValue) async throws
}

@MainActor final class EditorialRepository: EditorialRemote {
    private let client: SupabaseClient?
    init(client: SupabaseClient?) { self.client = client }
    private func authorized(_ owner: UUID) async throws -> SupabaseClient {
        guard let client, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        let admins: [JSONValue] = try await client.from("app_admins").select("user_id").eq("user_id", value: owner.uuidString).limit(1).execute().value
        guard !admins.isEmpty, try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
        return client
    }
    func load(owner: UUID, kind: EditorialKind, offset: Int) async throws -> EditorialSnapshot {
        let client = try await authorized(owner)
        async let categories: [JSONValue] = client.from("content_categories").select().order("display_order").order("name").execute().value
        async let contents: [JSONValue] = client.from("daily_contents").select().eq("type", value: kind.rawValue).order("created_at", ascending: false).order("id").range(from: offset, to: offset + 29).execute().value
        async let schedules: [JSONValue] = client.from("daily_content_schedule").select("content_id,type,display_date").eq("type", value: kind.rawValue).gte("display_date", value: LocalCalendar.key(.now)).order("display_date").execute().value
        let result = try await EditorialSnapshot(categories: categories, contents: contents, schedules: schedules)
        _ = try await authorized(owner)
        return result
    }
    func save(owner: UUID, draft: EditorialDraft) async throws -> JSONValue {
        let client = try await authorized(owner)
        var payload = draft.payload
        let categories: [JSONValue] = try await client.from("content_categories").select().execute().value
        guard draft.validation(categories: categories) == nil else { throw URLError(.badURL) }
        for attachment in [draft.image, draft.audio].compactMap({ $0 }) {
            _ = try await authorized(owner)
            let bucket = client.storage.from("daily-content-media"), path = attachment.path(owner: owner)
            do { try await bucket.upload(path, data: attachment.data, options: FileOptions(contentType: attachment.mime, upsert: false)) }
            catch {
                // Retry a confirmed identical object; never overwrite another file.
                let existing = try await bucket.download(path: path)
                guard existing == attachment.data else { throw error }
            }
            payload = payload.setting(attachment.field, .string(try bucket.getPublicURL(path: path).absoluteString))
        }
        _ = try await authorized(owner)
        let params: [String: JSONValue] = ["p_content": payload, "p_date": draft.date.isEmpty ? .null : .string(draft.date)]
        _ = try await client.rpc("save_daily_content", params: params).execute()
        let confirmed: JSONValue = try await client.from("daily_contents").select().eq("id", value: payload["id"].string.orEmpty).single().execute().value
        guard payload.object.allSatisfy({ confirmed[$0.key] == $0.value }) else { throw URLError(.cannotParseResponse) }
        if !draft.date.isEmpty {
            let rows: [JSONValue] = try await client.from("daily_content_schedule").select("content_id").eq("type", value: payload["type"].string.orEmpty).eq("display_date", value: draft.date).execute().value
            guard rows.contains(where: { $0["content_id"] == payload["id"] }) else { throw URLError(.cannotParseResponse) }
        }
        _ = try await authorized(owner)
        return confirmed
    }
    func saveCategory(owner: UUID, row: JSONValue) async throws -> JSONValue {
        guard EditorialDraft.validCategory(row) else { throw URLError(.badURL) }
        let client = try await authorized(owner)
        try await client.from("content_categories").upsert(row).execute()
        let confirmed: JSONValue = try await client.from("content_categories").select().eq("id", value: row["id"].string.orEmpty).single().execute().value
        guard row.object.allSatisfy({ confirmed[$0.key] == $0.value }) else { throw URLError(.cannotParseResponse) }
        _ = try await authorized(owner); return confirmed
    }
    func delete(owner: UUID, id: String, category: Bool) async throws {
        guard UUID(uuidString: id) != nil else { throw URLError(.badURL) }
        let client = try await authorized(owner), table = category ? "content_categories" : "daily_contents"
        try await client.from(table).delete().eq("id", value: id).execute()
        let remaining: [JSONValue] = try await client.from(table).select("id").eq("id", value: id).execute().value
        guard remaining.isEmpty else { throw URLError(.cannotParseResponse) }
        _ = try await authorized(owner)
    }
    func unschedule(owner: UUID, row: JSONValue) async throws {
        guard let id = row["content_id"].string, UUID(uuidString: id) != nil, let kind = EditorialKind(rawValue: row["type"].string.orEmpty), EditorialDraft.validDate(row["display_date"].string.orEmpty) else { throw URLError(.badURL) }
        let client = try await authorized(owner), date = row["display_date"].string.orEmpty
        // Do not remove a replacement made by another administrator since this screen loaded.
        try await client.from("daily_content_schedule").delete().eq("content_id", value: id).eq("type", value: kind.rawValue).eq("display_date", value: date).execute()
        let remaining: [JSONValue] = try await client.from("daily_content_schedule").select("content_id").eq("content_id", value: id).eq("type", value: kind.rawValue).eq("display_date", value: date).execute().value
        guard remaining.isEmpty else { throw URLError(.cannotParseResponse) }
        _ = try await authorized(owner)
    }
}

private extension Optional where Wrapped == String { var orEmpty: String { self ?? "" } }
