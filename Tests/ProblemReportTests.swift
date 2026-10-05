import XCTest
@testable import CoranNative

final class ProblemReportTests: XCTestCase {
    func testDescriptionAndScreenshotPathsMatchExistingBackend() throws {
        let owner = UUID()
        let report = try ProblemReport.create(owner: owner, type: .audio, description: "  Audio arrêté  ", screenshot: true, version: "0.1.0")
        XCTAssertEqual(report.description, "Audio arrêté")
        XCTAssertEqual(report.screenshot_path, owner.uuidString.lowercased() + "/" + report.id.uuidString.lowercased() + ".jpg")
        XCTAssertTrue(report.valid)
        XCTAssertThrowsError(try ProblemReport.create(owner: owner, type: .bug, description: " \n ", screenshot: false, version: "1"))
        XCTAssertThrowsError(try ProblemReport.create(owner: owner, type: .bug, description: String(repeating: "é", count: 501), screenshot: false, version: "1"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(report)) as? [String: Any])
        XCTAssertEqual(json["platform"] as? String, "ios"); XCTAssertEqual(json["status"] as? String, "open")
        XCTAssertNotNil(json["user_id"]); XCTAssertNil(json["userId"])
    }
    @MainActor func testOutboxSurvivesLostConfirmationAndRetriesSameIDWithoutDuplicate() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let owner = UUID(), remote = ReportRemoteFixture()
        var library = ProblemReportLibrary(directory: directory, remote: remote); library.select(owner)
        let id = try library.enqueue(type: .bug, description: "Test technique", screenshot: nil, version: "1")
        await library.synchronize(); XCTAssertEqual(library.pending.map(\.id), [id])
        library = ProblemReportLibrary(directory: directory, remote: remote); library.select(owner)
        XCTAssertEqual(library.pending.map(\.id), [id])
        await library.synchronize(); XCTAssertTrue(library.pending.isEmpty)
        XCTAssertEqual(remote.stored.count, 1); XCTAssertEqual(remote.attempts, [id, id])
        let reopened = ProblemReportLibrary(directory: directory); reopened.select(owner); XCTAssertTrue(reopened.pending.isEmpty)
    }
    @MainActor func testAccountIsolationAndPhotoPersistedBeforeSync() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = UUID(), second = UUID(), library = ProblemReportLibrary(directory: directory)
        library.select(first)
        let photo = Data([0xff, 0xd8, 0xff, 0xd9])
        let id = try library.enqueue(type: .display, description: "Test capture", screenshot: photo, version: "1")
        let file = directory.appendingPathComponent(first.uuidString.lowercased()).appendingPathComponent(id.uuidString.lowercased() + ".jpg")
        XCTAssertEqual(try Data(contentsOf: file), photo)
        library.select(second); XCTAssertTrue(library.pending.isEmpty)
        library.select(first); XCTAssertEqual(library.pending.map(\.id), [id])
        library.select(nil); XCTAssertTrue(library.pending.isEmpty)
        XCTAssertThrowsError(try library.enqueue(type: .other, description: "Déconnecté", screenshot: nil, version: "1"))
    }
    @MainActor func testOldConfirmationCannotClearNewAccountOutbox() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = UUID(), second = UUID(), remote = SuspendedReportRemote()
        let library = ProblemReportLibrary(directory: directory, remote: remote); library.select(first)
        let firstID = try library.enqueue(type: .bug, description: "Compte A", screenshot: nil, version: "1")
        let sync = Task { await library.synchronize() }
        while remote.confirmation == nil { await Task.yield() }
        library.select(second)
        let secondID = try library.enqueue(type: .audio, description: "Compte B", screenshot: nil, version: "1")
        remote.confirmation?.resume(); remote.confirmation = nil
        await sync.value
        XCTAssertEqual(library.owner, second); XCTAssertEqual(library.pending.map(\.id), [secondID])
        library.select(first); XCTAssertEqual(library.pending.map(\.id), [firstID])
    }
    @MainActor func testNewReportQueuedDuringUploadIsDrainedInSameSynchronization() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let owner = UUID(), remote = SuspendedReportRemote()
        let library = ProblemReportLibrary(directory: directory, remote: remote); library.select(owner)
        let first = try library.enqueue(type: .bug, description: "Premier", screenshot: nil, version: "1")
        let sync = Task { await library.synchronize() }
        while remote.confirmation == nil { await Task.yield() }
        let second = try library.enqueue(type: .audio, description: "Deuxième", screenshot: nil, version: "1")
        remote.confirmation?.resume(); remote.confirmation = nil
        await sync.value
        XCTAssertEqual(remote.sent, [first, second]); XCTAssertTrue(library.pending.isEmpty)
    }
}
@MainActor private final class SuspendedReportRemote: ProblemReportRemote {
    var confirmation: CheckedContinuation<Void, Never>?
    var sent: [UUID] = []
    func send(_ report: ProblemReport, screenshot: URL?) async throws {
        sent.append(report.id)
        if sent.count == 1 { await withCheckedContinuation { confirmation = $0 } }
    }
}
@MainActor private final class ReportRemoteFixture: ProblemReportRemote {
    var stored: Set<UUID> = []
    var attempts: [UUID] = []
    func send(_ report: ProblemReport, screenshot: URL?) async throws {
        attempts.append(report.id); stored.insert(report.id)
        if attempts.count == 1 { throw URLError(.networkConnectionLost) }
    }
}
