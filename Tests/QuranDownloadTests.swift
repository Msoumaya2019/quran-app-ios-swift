import XCTest
import ZIPFoundation
@testable import CoranNative

private actor PreparationProbe {
    var counts: [Int] = []
    func append(_ value: Int) { counts.append(value) }
}

final class QuranDownloadTests: XCTestCase {
    @MainActor func testNativeTransferReportsActualBytesAndRetainsCompletedFile() async throws {
        let status = QuranDownloadStatus.shared
        let installedBefore = QuranResourceService.shared.isReady(.edition1441)
        status.written = 0; status.expected = 0
        let url = try XCTUnwrap(URL(string: "https://files.quran.app/hafs/madani_1441/zips/images_1440.zip"))
        let (file, response) = try await QuranDownloadTransfer().download(url)
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let size = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as? NSNumber)?.int64Value ?? 0
        XCTAssertGreaterThan(size, 1_000_000)
        // Delegate updates are delivered to the MainActor independently of the completion.
        for _ in 0..<20 where status.written != size { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(status.written, size)
        XCTAssertEqual(QuranResourceService.shared.isReady(.edition1441), installedBefore)
        if status.expected > 0 { XCTAssertEqual(status.expected, size); XCTAssertEqual(status.progress, 1) }
        else { XCTAssertNil(status.progress) }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: destination) }
        let probe = PreparationProbe(), start = Date()
        try await QuranResourceService.prepareArchive(file, into: destination) { await probe.append($0) }
        let counts = await probe.counts
        XCTAssertEqual(counts, (1...604).map { $0 * 15 })
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("ready-v1"), encoding: .utf8), "9060")
        let images = try FileManager.default.contentsOfDirectory(at: destination, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }
        XCTAssertEqual(images.count, 9060)
        print("[Quran preparation] 9060 verified images in \(Date().timeIntervalSince(start)) seconds")
    }
    func testIncompleteArchiveNeverBecomesReady() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archiveURL = root.appendingPathComponent("incomplete.zip")
        _ = try Archive(url: archiveURL, accessMode: .create)
        let output = root.appendingPathComponent("prepared")
        do { try await QuranResourceService.prepareArchive(archiveURL, into: output); XCTFail("Incomplete archive accepted") } catch {}
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.appendingPathComponent("ready-v1").path))
    }
}
