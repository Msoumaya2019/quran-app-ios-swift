import XCTest
@testable import CoranNative

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
    }
}
