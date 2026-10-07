import Foundation
import Combine
import CryptoKit
import Supabase
import AVFoundation

@MainActor final class DailyContentMediaService: ObservableObject {
    private let client: SupabaseClient?
    private let baseURL: URL?
    private let directory: URL
    init(client: SupabaseClient?, baseURL: URL? = nil, directory: URL? = nil) {
        self.client = client; self.baseURL = baseURL ?? (try? BackendConfiguration.load().url)
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("DailyContentImages")
    }
    nonisolated static func privatePath(_ url: URL, base: URL) -> String? {
        let prefix = "/storage/v1/object/public/daily-content-media/"
        guard url.scheme == "https", url.host == base.host, url.port == base.port,
              url.user == nil, url.password == nil, url.path.hasPrefix(prefix) else { return nil }
        let path = String(url.path.dropFirst(prefix.count))
        guard !path.isEmpty, path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }) else { return nil }
        return path
    }
    func cacheURL(_ raw: String, owner: UUID?) -> URL {
        let key = SHA256.hash(data: Data(((owner?.uuidString ?? "anonymous") + "\n" + raw).utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(key + ".jpg")
    }
    private func resolved(_ url: URL) async throws -> URL {
        if let baseURL, let path = Self.privatePath(url, base: baseURL) {
            guard let client else { throw URLError(.notConnectedToInternet) }
            return try await client.storage.from("daily-content-media").createSignedURL(path: path, expiresIn: 3600)
        }
        return url
    }
    func audio(_ raw: String, owner: UUID?) async throws -> Data {
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw URLError(.badURL) }
        let file = cacheURL(raw, owner: owner).deletingPathExtension().appendingPathExtension("audio")
        if let cached = await Task.detached(priority: .userInitiated, operation: { try? Data(contentsOf: file) }).value { return cached }
        let (bytes, response) = try await URLSession.shared.data(from: resolved(url))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), !bytes.isEmpty, bytes.count <= 30 * 1024 * 1024 else { throw URLError(.cannotDecodeContentData) }
        guard try await Task.detached(priority: .userInitiated, operation: { try AVAudioPlayer(data: bytes).duration > 0 }).value else { throw URLError(.cannotDecodeContentData) }
        let directory = directory
        try? await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }.value
        return bytes
    }
    func image(_ raw: String, owner: UUID?) async throws -> Data {
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw URLError(.badURL) }
        let file = cacheURL(raw, owner: owner)
        if let cached = await Task.detached(priority: .userInitiated, operation: { try? Data(contentsOf: file) }).value { return cached }
        let (bytes, response) = try await URLSession.shared.data(from: resolved(url))
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), !bytes.isEmpty, bytes.count <= 10 * 1024 * 1024 else { throw URLError(.cannotDecodeContentData) }
        let prepared = try await ProblemScreenshot.prepare(bytes)
        let directory = directory
        try? await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try prepared.write(to: file, options: .atomic)
        }.value
        return prepared
    }
}
