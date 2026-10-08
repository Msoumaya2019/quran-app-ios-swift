import Foundation
import Combine

@MainActor final class TajweedDownloadStatus: ObservableObject {
    static let shared = TajweedDownloadStatus()
    @Published var phase = "idle"
    @Published var completed = 0
    @Published var fileProgress = 0.0
    @Published var written: Int64 = 0
    @Published var expected: Int64 = 0
    @Published var error: String?
    var progress: Double { min(1, (Double(completed) + fileProgress) / 604) }
}

/// Online bootstrap. Durable offline datasets must come from Foundation Content Sync,
/// not a build-time dump of regular API responses (Developer Terms §3.1).
actor TajweedMushafResourceService {
    static let shared = TajweedMushafResourceService()
    static let offlineRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Quran/qcf_tajweed_v4/" + TajweedMushafPage.version)
    nonisolated static var installed: Bool { FileManager.default.fileExists(atPath: offlineRoot.appendingPathComponent("ready.json").path) }
    private var installation: Task<Void, Error>?
    struct Resource: Sendable { let page: TajweedMushafPage; let directory: URL }
    private var resources: [Int: Resource] = [:]
    private var pending: [Int: Task<Resource, Error>] = [:]
    private var retained = Set<Int>()
    private let root: URL
    private var repository: TajweedMushafRepository?
    func configure(repository: TajweedMushafRepository) { self.repository = repository }
    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("CoranNative-QCF-" + UUID().uuidString)) { self.root = root }
    func setWindow(page: Int) {
        retained = Set(max(1, page - 1)...min(604, page + 1))
        resources = resources.filter { retained.contains($0.key) }
    }
    func page(_ number: Int) async throws -> Resource {
        guard (1...604).contains(number) else { throw URLError(.badURL) }
        let offline = Self.offlineRoot.appendingPathComponent(String(number))
        if Self.installed, let data = try? Data(contentsOf: offline.appendingPathComponent("data.json")),
           let page = try? JSONDecoder().decode(TajweedMushafPage.self, from: data),
           ["page.woff2", "basmala.woff2", "surahs.woff2"].allSatisfy({ Self.validFont(offline.appendingPathComponent($0)) }) {
            try Data(TajweedMushafHTML.document(page).utf8).write(to: offline.appendingPathComponent("page.html"), options: .atomic)
            return Resource(page: page, directory: offline)
        }
        if let value = resources[number] { return value }
        if let task = pending[number] { return try await task.value }
        guard let repository else { throw ConfigurationError.missing }
        let root = root
        let task = Task<Resource, Error> {
            let data = try await repository.page(number)
            let page = try TajweedMushafPage.decodeAPI(data, page: number)
            let directory = root.appendingPathComponent(String(number))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Only the three render candidates use temporary fonts. No offline-ready
            // marker is created until an authorized Content Sync copy is available.
            let fonts = [
                ("page.woff2", "https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/woff2/p\(number).woff2"),
                ("basmala.woff2", "https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/woff2/p1.woff2"),
                ("surahs.woff2", "https://quran.com/fonts/quran/surah-names/v1/sura_names.woff2")
            ]
            for (name, path) in fonts {
                let (font, response) = try await URLSession.shared.data(from: URL(string: path)!)
                guard (response as? HTTPURLResponse)?.statusCode == 200, font.count > 48,
                      font.prefix(4) == Data("wOF2".utf8) else { throw URLError(.cannotDecodeContentData) }
                try font.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
            let html = try TajweedMushafHTML.document(page)
            try Data(html.utf8).write(to: directory.appendingPathComponent("page.html"), options: .atomic)
            return Resource(page: page, directory: directory)
        }
        pending[number] = task
        defer { pending[number] = nil }
        let value = try await task.value
        if retained.contains(number) { resources[number] = value }
        return value
    }
    private static func validFont(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return data.count > 48 && data.prefix(4) == Data("wOF2".utf8)
    }
    private static func downloadFont(_ path: String, to output: URL, progress: Bool = false) async throws {
        if validFont(output) { return }
        let (file, response) = try await QuranDownloadTransfer(report: { written, expected in
            guard progress else { return }
            Task { @MainActor in let s = TajweedDownloadStatus.shared; s.written = written; s.expected = expected; s.fileProgress = expected > 0 ? min(1, Double(written) / Double(expected)) : 0 }
        }).download(URL(string: path)!)
        defer { try? FileManager.default.removeItem(at: file) }
        guard (response as? HTTPURLResponse)?.statusCode == 200, validFont(file) else { throw URLError(.cannotDecodeContentData) }
        try Data(contentsOf: file).write(to: output, options: .atomic)
    }
    func download() async throws {
        if let installation { try await installation.value; return }
        guard let repository else { throw ConfigurationError.missing }
        let task = Task { try await self.install(repository) }
        installation = task
        defer { installation = nil }
        do { try await task.value }
        catch { await MainActor.run { TajweedDownloadStatus.shared.phase = "error"; TajweedDownloadStatus.shared.error = "Le téléchargement a échoué. Les fichiers validés sont conservés pour reprendre." }; throw error }
    }
    private func install(_ repository: TajweedMushafRepository) async throws {
        await MainActor.run { let s = TajweedDownloadStatus.shared; s.phase = "sync"; s.completed = 0; s.fileProgress = 0; s.error = nil }
        var query = ["bootstrap": "true", "per_page": "100"]
        var token: String?, found = false
        var cursors = Set<String>()
        while true {
            let data = try await repository.sync(query: query)
            let envelope = try JSONDecoder().decode(JSONValue.self, from: data)
            if envelope["mutations"].array.contains(where: { $0["resource_group"].string == "mushafs" && $0["resource_id"].int == 19 && $0["snapshot_url"].string != nil }) { found = true }
            if envelope["has_more"].bool == true {
                guard let path = envelope["next_page_url"].string, let parts = URLComponents(string: path), parts.path == "/api/v4/resources/sync", parts.host == nil, cursors.insert(path).inserted else { throw URLError(.cannotParseResponse) }
                var next: [String: String] = [:]
                for item in parts.queryItems ?? [] { if let value = item.value { next[item.name] = value } }
                query = next
            } else { token = envelope["next_sync_token"].string; break }
        }
        guard found, let token else { throw URLError(.cannotParseResponse) }
        let snapshot = try await repository.snapshot()
        let pages = try TajweedMushafPage.decodeSnapshot(snapshot)
        let fm = FileManager.default, common = Self.offlineRoot.appendingPathComponent("common")
        try fm.createDirectory(at: common, withIntermediateDirectories: true)
        for (name, url) in [("basmala.woff2", "https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/woff2/p1.woff2"), ("surahs.woff2", "https://quran.com/fonts/quran/surah-names/v1/sura_names.woff2")] {
            try await Self.downloadFont(url, to: common.appendingPathComponent(name))
        }
        await MainActor.run { TajweedDownloadStatus.shared.phase = "downloading" }
        for page in pages {
            let directory = Self.offlineRoot.appendingPathComponent(String(page.number))
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            try await Self.downloadFont("https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/woff2/p\(page.number).woff2", to: directory.appendingPathComponent("page.woff2"), progress: true)
            for name in ["basmala.woff2", "surahs.woff2"] {
                let local = directory.appendingPathComponent(name), shared = common.appendingPathComponent(name)
                if !Self.validFont(local) {
                    try? fm.removeItem(at: local)
                    do { try fm.linkItem(at: shared, to: local) }
                    catch { try Data(contentsOf: shared).write(to: local, options: .atomic) }
                }
            }
            try JSONEncoder().encode(page).write(to: directory.appendingPathComponent("data.json"), options: .atomic)
            try Data(TajweedMushafHTML.document(page).utf8).write(to: directory.appendingPathComponent("page.html"), options: .atomic)
            await MainActor.run { let s = TajweedDownloadStatus.shared; s.completed = page.number; s.fileProgress = 0 }
        }
        let marker: JSONValue = .object(["version": .string(TajweedMushafPage.version), "token": .string(token), "checkedAt": .number(Date().timeIntervalSince1970)])
        try JSONEncoder().encode(marker).write(to: Self.offlineRoot.appendingPathComponent("ready.json"), options: .atomic)
        resources.removeAll()
        await MainActor.run { TajweedDownloadStatus.shared.phase = "ready" }
    }
    func refreshIfNeeded() async {
        guard Self.installed, installation == nil, let data = try? Data(contentsOf: Self.offlineRoot.appendingPathComponent("ready.json")), let marker = try? JSONDecoder().decode(JSONValue.self, from: data), let checked = marker["checkedAt"].int, Date().timeIntervalSince1970 - Double(checked) >= 7 * 86400 else { return }
        try? await download() // Failed refresh retains the last synced offline copy.
    }
}
