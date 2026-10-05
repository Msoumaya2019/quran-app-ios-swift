import Foundation
import Supabase

@MainActor protocol ProblemReportRemote {
    func send(_ report: ProblemReport, screenshot: URL?) async throws
}
@MainActor final class ProblemReportRepository: ProblemReportRemote {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    private func authenticate(_ owner: UUID) async throws {
        guard try await client.auth.session.user.id == owner else { throw URLError(.userAuthenticationRequired) }
    }
    func send(_ report: ProblemReport, screenshot: URL?) async throws {
        guard report.valid else { throw URLError(.badURL) }
        try await authenticate(report.user_id)
        if let path = report.screenshot_path {
            guard let screenshot else { throw CocoaError(.fileNoSuchFile) }
            let bucket = client.storage.from("problem-report-screenshots")
            do { try await bucket.upload(path, fileURL: screenshot, options: FileOptions(contentType: "image/jpeg", upsert: false)) }
            catch { guard try await bucket.exists(path: path) else { throw error } }
        }
        try await authenticate(report.user_id)
        try await client.from("app_problem_reports").upsert(report, onConflict: "id", ignoreDuplicates: true).execute()
        struct Confirmation: Decodable { let id: UUID; let user_id: UUID }
        let rows: [Confirmation] = try await client.from("app_problem_reports").select("id,user_id")
            .eq("id", value: report.id.uuidString).eq("user_id", value: report.user_id.uuidString).limit(1).execute().value
        guard rows.contains(where: { $0.id == report.id && $0.user_id == report.user_id }) else { throw URLError(.cannotParseResponse) }
    }
}
