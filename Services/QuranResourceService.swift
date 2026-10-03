import Foundation
import ZIPFoundation

actor QuranResourceService {
    static let shared = QuranResourceService()
    private var download: Task<Void, Error>?
    nonisolated var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CoranNative/Quran/coran_1441", isDirectory: true)
    }
    nonisolated func lineURL(page: Int, line: Int) -> URL {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reader-fixtures"), let root = Bundle.main.resourceURL {
            return root.appendingPathComponent("ReaderTestFixtures/\(String(format: "%03d-%02d.png", page, line))")
        }
        #endif
        return directory.appendingPathComponent(String(format: "%03d-%02d.png", page, line))
    }
    nonisolated func isReady(_ source: QuranSource) -> Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-reader-fixtures") { return true }
        #endif
        return source.renderingType == .pageImage || FileManager.default.fileExists(atPath: directory.appendingPathComponent("ready-v1").path)
    }
    func ensureReady(_ source: QuranSource) async throws {
        guard !isReady(source) else { return }
        if let download { try await download.value; return }
        let task = Task { try await self.install() }
        download = task
        defer { download = nil }
        try await task.value
    }
    private func install() async throws {
        let url = URL(string: "https://files.quran.app/hafs/madani_1441/zips/images_1440.zip")!
        let (temporary, response) = try await URLSession.shared.download(from: url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let destination = directory
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            let archive = try Archive(url: temporary, accessMode: .read)
            // Only known numeric paths are extracted; arbitrary archive paths never reach disk.
            for page in 1...604 {
                for line in 1...15 {
                    guard let entry = archive["width_1440/\(page)/\(line).png"], entry.type == .file, entry.uncompressedSize < 4_000_000 else { throw URLError(.cannotDecodeContentData) }
                    let output = destination.appendingPathComponent(String(format: "%03d-%02d.png", page, line))
                    if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
                    _ = try archive.extract(entry, to: output)
                }
            }
            try Data("9060".utf8).write(to: destination.appendingPathComponent("ready-v1"), options: .atomic)
        }.value
    }
}
