import Foundation

/// Online bootstrap. Durable offline datasets must come from Foundation Content Sync,
/// not a build-time dump of regular API responses (Developer Terms §3.1).
actor TajweedMushafResourceService {
    static let shared = TajweedMushafResourceService()
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
}
