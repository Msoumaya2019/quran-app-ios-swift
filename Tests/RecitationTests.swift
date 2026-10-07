import XCTest
@testable import CoranNative

@MainActor private final class RecordingRemoteProbe: RecitationRemote {
    var offline = false
    var failMetadataOnce = false
    var uploaded: Set<String> = []
    var rows: [Recitation] = []
    var attempts = 0
    var delay = false
    var rejectedID: String?
    var reviewRows: [RecitationFeedback] = []
    var feedbackDownloads = 0
    func upload(_ item: Recitation, file: URL) async throws {
        attempts += 1
        if delay { try await Task.sleep(nanoseconds: 50_000_000) }
        if offline { throw URLError(.notConnectedToInternet) }
        if item.id == rejectedID { throw URLError(.cannotParseResponse) }
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
    func reviews(_ item: Recitation) async throws -> [RecitationFeedback] {
        if delay { try await Task.sleep(nanoseconds: 50_000_000) }
        if offline { throw URLError(.notConnectedToInternet) }
        return reviewRows
    }
    func feedbackAudio(_ item: Recitation, review: RecitationFeedback) async throws -> Data {
        if offline { throw URLError(.notConnectedToInternet) }
        feedbackDownloads += 1; return Data([1, 2, 3, 4])
    }
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
    func testOneRejectedRecordingDoesNotBlockOtherPendingRecordings() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let remote = RecordingRemoteProbe(), library = RecitationLibrary(storage: RecitationStorage(directory: root.appendingPathComponent("saved")), remote: remote)
        let user = UUID(); await library.select(user)
        let file = try source(in: root)
        try await library.save(source: file, start: 1, end: 1, durationMs: 1000, user: user)
        let rejected = library.items[0].id
        try await library.save(source: file, start: 2, end: 2, durationMs: 1000, user: user)
        remote.rejectedID = rejected
        await library.synchronize()
        XCTAssertEqual(remote.rows.count, 1)
        XCTAssertFalse(library.items.first(where: { $0.id == rejected })!.synced)
        XCTAssertEqual(library.items.filter(\.synced).count, 1)
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
    func testFeedbackTextAndAudioSurviveOfflineReopenAndRemainAccountIsolated() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let remote = RecordingRemoteProbe(), storage = RecitationStorage(directory: root.appendingPathComponent("saved"))
        let user = UUID(), library = RecitationLibrary(storage: storage, remote: remote)
        await library.select(user)
        try await library.save(source: source(in: root), start: 1, end: 7, durationMs: 2500, user: user)
        await library.synchronize(); let item = library.items[0]
        let review = RecitationFeedback(id: UUID().uuidString, recitation_id: item.id, verse_id: 3, comment: "Revoir la prononciation", voice_path: "feedback/\(UUID())/voice.m4a", created_at: "2026-10-07T10:00:00Z", resolved_at: nil)
        remote.reviewRows = [review]; await library.loadReviews(item)
        let file = try await library.feedbackPlayable(review, for: item)
        XCTAssertEqual(try Data(contentsOf: file), Data([1, 2, 3, 4]))
        remote.offline = true
        let reopened = RecitationLibrary(storage: storage, remote: remote)
        await reopened.select(user); await reopened.loadReviews(item)
        XCTAssertEqual(reopened.reviews[item.id], [review])
        let cached = try await reopened.feedbackPlayable(review, for: item)
        XCTAssertEqual(cached, file); XCTAssertEqual(remote.feedbackDownloads, 1)
        await reopened.select(UUID()); XCTAssertTrue(reopened.reviews.isEmpty)
        do { _ = try await reopened.feedbackPlayable(review, for: item); XCTFail("Foreign account accessed cached feedback") } catch {}
    }
    func testLateFeedbackResponseCannotRestorePreviousAccountAndMalformedRowsAreRejected() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let remote = RecordingRemoteProbe(), storage = RecitationStorage(directory: root.appendingPathComponent("saved"))
        let user = UUID(), library = RecitationLibrary(storage: storage, remote: remote)
        await library.select(user); try await library.save(source: source(in: root), start: 1, end: 7, durationMs: 2500, user: user)
        await library.synchronize(); let item = library.items[0]
        remote.reviewRows = [RecitationFeedback(id: UUID().uuidString, recitation_id: item.id, verse_id: 2, comment: "Correction", voice_path: nil, created_at: "2026-10-07", resolved_at: nil)]
        remote.delay = true
        let request = Task { await library.loadReviews(item) }; try await Task.sleep(nanoseconds: 10_000_000)
        await library.select(UUID()); await request.value
        XCTAssertTrue(library.reviews.isEmpty)
        let malformed = RecitationFeedback(id: UUID().uuidString, recitation_id: item.id, verse_id: 200, comment: "Wrong verse", voice_path: nil, created_at: "2026-10-07", resolved_at: nil)
        do { try await storage.saveReviews([malformed], for: item); XCTFail("Unrelated verse accepted") } catch {}
        XCTAssertFalse(RecitationFeedback.safeVoicePath("feedback/\(UUID())/../../secret"))
    }
    func testChangedFeedbackVoiceInvalidatesOldOfflineAudio() async throws {
        let root = directory(); defer { try? FileManager.default.removeItem(at: root) }
        let storage = RecitationStorage(directory: root.appendingPathComponent("saved")), user = UUID()
        let item = try await storage.save(source: source(in: root), start: 1, end: 7, durationMs: 2500, owner: user)
        let id = UUID().uuidString, admin = UUID()
        let old = RecitationFeedback(id: id, recitation_id: item.id, verse_id: nil, comment: "Observation", voice_path: "feedback/\(admin)/old.m4a", created_at: "2026-10-07", resolved_at: nil)
        try await storage.saveReviews([old], for: item)
        _ = try await storage.cacheFeedback(Data([1]), review: old, for: item)
        let updated = RecitationFeedback(id: id, recitation_id: item.id, verse_id: nil, comment: "Observation", voice_path: "feedback/\(admin)/new.m4a", created_at: "2026-10-07", resolved_at: nil)
        try await storage.saveReviews([updated], for: item)
        do { _ = try await storage.feedbackFile(updated, for: item); XCTFail("Old voice returned for updated feedback") } catch {}
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
