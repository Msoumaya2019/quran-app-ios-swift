import XCTest
@testable import CoranNative

@MainActor private final class RecordingRemoteProbe: RecitationRemote {
    var offline = false
    var failMetadataOnce = false
    var uploaded: Set<String> = []
    var rows: [Recitation] = []
    var attempts = 0
    var delay = false
    func upload(_ item: Recitation, file: URL) async throws {
        attempts += 1
        if delay { try await Task.sleep(nanoseconds: 50_000_000) }
        if offline { throw URLError(.notConnectedToInternet) }
        uploaded.insert(item.storagePath)
        if failMetadataOnce { failMetadataOnce = false; throw URLError(.networkConnectionLost) }
        var confirmed = item; confirmed.synced = true
        if !rows.contains(where: { $0.id == item.id }) { rows.append(confirmed) }
    }
    func list(owner: UUID) async throws -> [Recitation] {
        if delay { try await Task.sleep(nanoseconds: 50_000_000) }
        if offline { throw URLError(.notConnectedToInternet) }
        return rows.filter { $0.userID == owner }
    }
    func download(_ item: Recitation) async throws -> Data { throw URLError(.notConnectedToInternet) }
}
@MainActor private final class CaptureProbe: VoiceCaptureDevice {
    let file: URL
    var stopped = false
    init(file: URL) { self.file = file }
    var currentTime: Double { 2.5 }
    func record() -> Bool { do { try Data([1, 2, 3, 4]).write(to: file); return true } catch { return false } }
    func stop() { stopped = true }
}

@MainActor final class RecitationTests: XCTestCase {
    private func directory() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func source(in root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("source.m4a"); try Data([1, 2, 3, 4]).write(to: file); return file
    }
    func testLocalRecordingSurvivesReopenAndIsIsolatedByAccount() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let owner = UUID(), other = UUID(), file = try source(in: root)
        let storage = RecitationStorage(directory: root.appendingPathComponent("saved"))
        let item = try await storage.save(source: file, start: 1, end: 7, durationMs: 2500, owner: owner)
        let reopened = RecitationStorage(directory: root.appendingPathComponent("saved"))
        let entries = try await reopened.list(owner: owner), foreign = try await reopened.list(owner: other)
        XCTAssertEqual(entries, [item]); XCTAssertTrue(foreign.isEmpty); XCTAssertFalse(item.synced)
        let saved = try await reopened.file(for: item)
        XCTAssertEqual(try Data(contentsOf: saved), Data([1, 2, 3, 4]))
    }
    func testOfflineSaveRetryAndConcurrentSyncConfirmOnlyOnce() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = RecitationStorage(directory: root.appendingPathComponent("saved")), remote = RecordingRemoteProbe()
        let library = RecitationLibrary(storage: storage, remote: remote), user = UUID()
        await library.select(user)
        try await library.save(source: source(in: root), start: 1, end: 7, durationMs: 2500, user: user)
        remote.offline = true
        await library.synchronize()
        XCTAssertFalse(library.items[0].synced)
        remote.offline = false; remote.delay = true
        let first = Task { await library.synchronize() }
        while !library.syncing { await Task.yield() }
        await library.synchronize(); await first.value
        await library.synchronize()
        XCTAssertTrue(library.items[0].synced); XCTAssertEqual(remote.uploaded.count, 1); XCTAssertEqual(remote.rows.count, 1)
        XCTAssertEqual(remote.attempts, 2) // failed offline request, then one confirmed upload
    }
    func testMetadataFailureRetainsSameIDAndStoragePathForRetry() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let remote = RecordingRemoteProbe(), library = RecitationLibrary(storage: RecitationStorage(directory: root.appendingPathComponent("saved")), remote: remote)
        let user = UUID(); await library.select(user)
        try await library.save(source: source(in: root), start: 8, end: 10, durationMs: 2500, user: user)
        let original = library.items[0]
        remote.failMetadataOnce = true
        await library.synchronize()
        XCTAssertFalse(library.items[0].synced)
        await library.synchronize()
        XCTAssertEqual(library.items[0].id, original.id); XCTAssertEqual(remote.uploaded.count, 1); XCTAssertEqual(remote.rows.count, 1)
        XCTAssertTrue(library.items[0].synced)
    }
    func testDelayedResponseCannotRestorePreviousAccountRecordings() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let remote = RecordingRemoteProbe(), library = RecitationLibrary(storage: RecitationStorage(directory: root.appendingPathComponent("saved")), remote: remote)
        let owner = UUID(), other = UUID(); await library.select(owner)
        try await library.save(source: source(in: root), start: 1, end: 1, durationMs: 1000, user: owner)
        await library.synchronize()
        remote.delay = true
        let refresh = Task { await library.synchronize() }
        while !library.syncing { await Task.yield() }
        await library.select(other); await refresh.value
        XCTAssertEqual(library.owner, other); XCTAssertTrue(library.items.isEmpty)
    }
    func testDeniedMicrophoneDoesNotCreateCapture() async {
        var captures = 0
        let recorder = VoiceRecorderService(permission: { false }, factory: { captures += 1; return CaptureProbe(file: $0) })
        await recorder.start()
        XCTAssertEqual(captures, 0); XCTAssertFalse(recorder.recording); XCTAssertNotNil(recorder.error)
    }
    func testStoppedDraftCanBeSavedAndDiscardedWithoutDeletingSavedFile() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        var capture: CaptureProbe?
        let recorder = VoiceRecorderService(directory: root.appendingPathComponent("draft"), permission: { true }, factory: { let value = CaptureProbe(file: $0); capture = value; return value })
        await recorder.start(); XCTAssertTrue(recorder.recording)
        recorder.stop(); XCTAssertFalse(recorder.recording); XCTAssertEqual(recorder.elapsed, 2.5); XCTAssertTrue(capture?.stopped == true)
        let draft = try XCTUnwrap(recorder.draft)
        let storage = RecitationStorage(directory: root.appendingPathComponent("saved"))
        let item = try await storage.save(source: draft, start: 1, end: 7, durationMs: 2500, owner: UUID())
        recorder.discard(); XCTAssertFalse(FileManager.default.fileExists(atPath: draft.path))
        let saved = try await storage.file(for: item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.path))
    }
    func testPermissionResponseAfterDiscardCannotStartMicrophone() async {
        var continuation: CheckedContinuation<Bool, Never>?
        var captures = 0
        let recorder = VoiceRecorderService(permission: { await withCheckedContinuation { continuation = $0 } }, factory: { captures += 1; return CaptureProbe(file: $0) })
        let start = Task { await recorder.start() }
        while continuation == nil { await Task.yield() }
        recorder.discard(); continuation?.resume(returning: true); await start.value
        XCTAssertEqual(captures, 0); XCTAssertFalse(recorder.recording)
    }
    func testSupabasePayloadUsesExistingRNContract() throws {
        let user = UUID()
        let item = Recitation(id: "test-id", userID: user, start: 1, end: 7, durationMs: 2500, createdAt: "2026-10-04T10:00:00Z", storagePath: "\(user.uuidString.lowercased())/test-id.m4a", synced: false)
        let data = try JSONEncoder().encode(RecitationRow(item))
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value["recording_type"].string, "quran"); XCTAssertEqual(value["start_verse_id"].int, 1)
        XCTAssertEqual(value["end_verse_id"].int, 7); XCTAssertEqual(value["duration_ms"].int, 2500)
        XCTAssertEqual(value["storage_path"].string, item.storagePath); XCTAssertEqual(value["id"].string, item.id)
        XCTAssertNil(value["localFile"].string)
    }
    func testUnsafeLocalFilenameAndInvalidPassageAreRejected() async throws {
        XCTAssertFalse(Recitation.safeFilename("../../other.m4a")); XCTAssertFalse(Recitation.safeFilename("folder/file.m4a"))
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let file = try source(in: root), storage = RecitationStorage(directory: root.appendingPathComponent("saved"))
        do { _ = try await storage.save(source: file, start: 10, end: 1, durationMs: 1000, owner: UUID()); XCTFail("Invalid passage was saved") } catch {}
    }
}
