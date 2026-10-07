import Foundation
import ZIPFoundation

actor QuranResourceService {
    static let shared = QuranResourceService()
    static let lineCount = 604 * 15
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
        do { try await task.value }
        catch { await MainActor.run { QuranDownloadStatus.shared.phase = "error" }; throw error }
    }
    private func install() async throws {
        let url = URL(string: "https://files.quran.app/hafs/madani_1441/zips/images_1440.zip")!
        await MainActor.run { QuranDownloadStatus.shared.phase = "downloading"; QuranDownloadStatus.shared.written = 0; QuranDownloadStatus.shared.expected = 0 }
        let (temporary, response) = try await QuranDownloadTransfer().download(url)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        await MainActor.run { QuranDownloadStatus.shared.preparedLines = 0; QuranDownloadStatus.shared.phase = "installing" }
        try await Self.prepareArchive(temporary, into: directory) { completed in
            await MainActor.run { QuranDownloadStatus.shared.preparedLines = completed }
        }
        await MainActor.run { QuranDownloadStatus.shared.phase = "ready" }
    }
    static func prepareArchive(_ temporary: URL, into destination: URL, progress: @escaping @Sendable (Int) async -> Void = { _ in }) async throws {
        try await Task.detached(priority: .utility) {
            let fm = FileManager.default
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            let archive = try Archive(url: temporary, accessMode: .read)
            let expected = Set((1...604).flatMap { page in (1...15).map { "width_1440/\(page)/\($0).png" } })
            var entries: [String: Entry] = [:]; entries.reserveCapacity(lineCount)
            // ZIPFoundation's path subscript scans from the beginning each time.
            // Index once rather than rescanning thousands of central-directory entries per image.
            for entry in archive where expected.contains(entry.path) {
                guard entries[entry.path] == nil, entry.type == .file, entry.uncompressedSize > 0, entry.uncompressedSize < 4_000_000 else { throw URLError(.cannotDecodeContentData) }
                entries[entry.path] = entry
            }
            guard entries.count == lineCount else { throw URLError(.cannotDecodeContentData) }
            // Only known numeric paths are extracted; arbitrary archive paths never reach disk.
            for page in 1...604 {
                for line in 1...15 {
                    try Task.checkCancellation()
                    guard let entry = entries["width_1440/\(page)/\(line).png"] else { throw URLError(.cannotDecodeContentData) }
                    let output = destination.appendingPathComponent(String(format: "%03d-%02d.png", page, line))
                    if fm.fileExists(atPath: output.path) { try fm.removeItem(at: output) }
                    let checksum = try archive.extract(entry, to: output)
                    guard checksum == entry.checksum else { throw Archive.ArchiveError.invalidCRC32 }
                }
                await progress(page * 15)
            }
            try Data(String(lineCount).utf8).write(to: destination.appendingPathComponent("ready-v1"), options: .atomic)
        }.value
    }
}
