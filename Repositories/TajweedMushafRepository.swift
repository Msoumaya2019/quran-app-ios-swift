import Foundation
import Supabase

/// Uses the app's existing Supabase session; Foundation credentials stay on the server.
actor TajweedMushafRepository {
    private let client: SupabaseClient
    private let configuration: BackendConfiguration
    init(client: SupabaseClient, configuration: BackendConfiguration) {
        self.client = client
        self.configuration = configuration
    }
    private struct Body: Encodable {
        let path: String
        let query: [String: String]
    }
    func page(_ number: Int) async throws -> Data {
        guard (1...604).contains(number) else { throw URLError(.badURL) }
        return try await request(path: "verses/by_page/\(number)", query: [:])
    }
    func sync(query: [String: String]) async throws -> Data {
        try await request(path: "resources/sync", query: query)
    }
    func snapshot(query: [String: String] = [:]) async throws -> Data {
        try await request(path: "resources/snapshots/mushafs/19", query: query)
    }
    private func request(path: String, query: [String: String]) async throws -> Data {
        let session = try await client.auth.session
        var request = URLRequest(url: configuration.url.appendingPathComponent("functions/v1/quran-foundation"))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(configuration.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(path: path, query: query))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if response.statusCode == 401 { throw URLError(.userAuthenticationRequired) }
        guard response.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
