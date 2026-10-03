import Foundation
import Supabase

@MainActor protocol HomeRemote {
    func fetch(userID: UUID, cached: HomeSnapshot) async throws -> HomeSnapshot
}
@MainActor final class HomeRepository: HomeRemote {
    let client: SupabaseClient?
    init(client: SupabaseClient?) { self.client = client }
    struct StateRow: Decodable { let user_id: UUID; let data: JSONValue }
    struct ProfileRow: Decodable { let display_name: String }
    struct DateArgs: Encodable { let p_date: String }
    struct QuizArgs: Encodable { let p_day: String }
    func fetch(userID: UUID, cached: HomeSnapshot) async throws -> HomeSnapshot {
        guard let client else { throw ConfigurationError.missing }
        async let stateRequest: [StateRow] = client.from("user_state").select("user_id,data").eq("user_id", value: userID.uuidString).limit(1).execute().value
        async let profileRequest: [ProfileRow] = client.from("friend_profiles").select("display_name").eq("id", value: userID.uuidString).limit(1).execute().value
        let day = LocalCalendar.key(.now)
        async let contentRequest: [DailyContent] = client.rpc("daily_content_for_date", params: DateArgs(p_date: day)).execute().value
        async let quizRequest: JSONValue = client.rpc("quiz_snapshot", params: QuizArgs(p_day: day)).execute().value
        var next = cached
        let rows = try await stateRequest
        if let row = rows.first {
            guard row.user_id == userID, row.data["schema"].int == 1, row.data["userId"].string.map({ $0.lowercased() == userID.uuidString.lowercased() }) != false else { throw URLError(.badServerResponse) }
            next.state = row.data
        }
        if let profiles = try? await profileRequest { next.displayName = profiles.first?.display_name }
        if let contents = try? await contentRequest { next.contents = contents; next.contentDate = day }
        if let quiz = try? await quizRequest {
            next.quizAvailable = quiz["daily"] != .null
            let id = quiz["daily"]["id"].string
            next.quizDone = id != nil && quiz["responses"].array.contains { $0["questionId"].string == id }
            next.quizDate = day
        }
        next.fetchedAt = .now
        return next
    }
}
