import Foundation

/// Shared disk cache. A simultaneous play/prefetch request downloads a verse once.
actor QuranAudioCache {
    static let shared = QuranAudioCache()
    typealias Downloader = @Sendable (URL) async throws -> Data
    private let directory: URL
    private let downloader: Downloader
    private var pending: [String: Task<URL, Error>] = [:]
    init(directory: URL? = nil, downloader: @escaping Downloader = QuranAudioCache.download) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("QuranAudio")
        self.downloader = downloader
    }
    private static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else { throw URLError(.badServerResponse) }
        return data
    }
    func file(reciterID: String, verseID: Int) async throws -> URL {
        guard (1...6236).contains(verseID), ["ar.shaatree", "ar.husary", "ar.alafasy", "ar.minshawi"].contains(reciterID) else { throw URLError(.badURL) }
        let key = "\(reciterID)/\(verseID)"
        let folder = directory.appendingPathComponent(reciterID)
        let local = folder.appendingPathComponent("\(verseID).mp3")
        if let size = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size]) as? NSNumber, size.intValue > 0 { return local }
        if let task = pending[key] { return try await task.value }
        let downloader = downloader
        let task = Task {
            let remote = URL(string: "https://cdn.islamic.network/quran/audio/128/\(reciterID)/\(verseID).mp3")!
            let data = try await downloader(remote)
            guard !data.isEmpty else { throw URLError(.zeroByteResource) }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: local, options: .atomic)
            return local
        }
        pending[key] = task
        defer { pending[key] = nil }
        return try await task.value
    }
}
