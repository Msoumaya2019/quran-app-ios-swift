import XCTest
@testable import CoranNative

@MainActor private final class ModerationProbe: ModerationRemote {
    var suspensionCalls = 0
    func suspension(owner: UUID, user: UUID, reason: String?, until: Date?) async throws -> JSONValue {
        suspensionCalls += 1
        if fail { throw URLError(.notConnectedToInternet) }
        return reason.map { .object(["user_id": .string(user.uuidString), "reason": .string($0)]) } ?? .null
    }
    var fail = false
    var hold = false
    var waiting: CheckedContinuation<[JSONValue], Error>?
    var supplied: [JSONValue] = [.object(["id": .string("message"), "body": .string("Original")])]
    var feedbackIDs: [UUID] = []
    var voiceData: [Data] = []
    var verses: [Int] = []
    var suspendCorrection = false
    var correctionWaiting: CheckedContinuation<Void, Never>?
    func rows(owner: UUID, section: ModerationSection, offset: Int) async throws -> [JSONValue] {
        if fail { throw URLError(.userAuthenticationRequired) }
        if hold { return try await withCheckedThrowingContinuation { waiting = $0 } }
        return supplied
    }
    func profiles(owner: UUID, ids: [String]) async throws -> [JSONValue] { [] }
    func recording(owner: UUID, id: String) async throws -> JSONValue { .null }
    func audio(owner: UUID, row: JSONValue) async throws -> Data { throw URLError(.notConnectedToInternet) }
    func deleteMessage(owner: UUID, id: String) async throws -> JSONValue {
        if fail { throw URLError(.notConnectedToInternet) }
        return supplied[0].setting("deleted_at", .string("2026-10-05T10:00:00Z"))
    }
    func resolveReport(owner: UUID, id: String) async throws -> JSONValue { supplied[0].setting("status", .string("reviewed")) }
    func listened(owner: UUID, id: String) async throws -> JSONValue { supplied[0].setting("listened_at", .string("2026-10-05T10:00:00Z")) }
    func feedback(owner: UUID, recitation: String, id: UUID, comment: String) async throws { feedbackIDs.append(id); if fail { throw URLError(.networkConnectionLost) } }
    func voiceFeedback(owner: UUID, recitation: String, id: UUID, comment: String, data: Data) async throws { feedbackIDs.append(id); voiceData.append(data); if fail { throw URLError(.networkConnectionLost) } }
    func verseFeedback(owner: UUID, recitation: String, id: UUID, verseID: Int, comment: String, data: Data?) async throws {
        feedbackIDs.append(id); verses.append(verseID); if let data { voiceData.append(data) }
        if suspendCorrection { await withCheckedContinuation { correctionWaiting = $0 } }
        if fail { throw URLError(.networkConnectionLost) }
    }
}
final class ModerationTests: XCTestCase {
    @MainActor func testSocialSuspensionRequiresServerConfirmationAndProtectsAccounts() async {
        let remote = ModerationProbe(), library = ModerationLibrary(remote: remote), owner = UUID(), user = UUID()
        let row: JSONValue = .object(["id": .string(user.uuidString), "suspension": .null, "protected": .bool(false)])
        remote.supplied = [row]; library.select(owner); await library.load(.members)
        remote.fail = true
        let failed = await library.suspension(row, reason: "Test", until: nil)
        XCTAssertFalse(failed); XCTAssertEqual(library.items[0]["suspension"], .null)
        remote.fail = false
        let confirmed = await library.suspension(row, reason: "Test", until: nil)
        XCTAssertTrue(confirmed); XCTAssertEqual(library.items[0]["suspension"]["reason"].string, "Test")
        let restored = await library.suspension(row, reason: nil, until: nil)
        XCTAssertTrue(restored); XCTAssertEqual(library.items[0]["suspension"], .null)
        let calls = remote.suspensionCalls
        let protected = await library.suspension(row.setting("protected", .bool(true)), reason: "Test", until: nil)
        let selfSuspension = await library.suspension(row.setting("id", .string(owner.uuidString)), reason: "Test", until: nil)
        XCTAssertFalse(protected); XCTAssertFalse(selfSuspension); XCTAssertEqual(remote.suspensionCalls, calls)
    }
    private var recording: JSONValue { .object(["id": .string("recording"), "recording_type": .string("quran"), "start_verse_id": .number(7), "end_verse_id": .number(10)]) }
    @MainActor func testVerseCorrectionIsLimitedToRecordedPassageAndNotInvocation() async {
        let remote = ModerationProbe(), library = ModerationLibrary(remote: remote); library.select(UUID())
        for verse in [0, 6, 11, 6237] {
            let sent = await library.feedback(recording, id: UUID(), comment: "Observation", verseID: verse)
            XCTAssertFalse(sent)
        }
        let invocation = recording.setting("recording_type", .string("invocation"))
        let sent = await library.feedback(invocation, id: UUID(), comment: "Observation", verseID: 7)
        XCTAssertFalse(sent); XCTAssertTrue(remote.verses.isEmpty)
        XCTAssertFalse(ModerationRepository.validVerse(7, in: recording.setting("end_verse_id", .number(6))))
    }
    @MainActor func testWrittenVerseCorrectionRetriesSameRequestWithoutGeneralFeedback() async {
        let remote = ModerationProbe(), library = ModerationLibrary(remote: remote), request = UUID(); library.select(UUID())
        remote.fail = true
        let first = await library.feedback(recording, id: request, comment: "Observation", verseID: 9)
        XCTAssertFalse(first)
        remote.fail = false
        let retry = await library.feedback(recording, id: request, comment: "Observation", verseID: 9)
        XCTAssertTrue(retry); XCTAssertEqual(remote.verses, [9, 9]); XCTAssertEqual(remote.feedbackIDs, [request, request]); XCTAssertTrue(remote.voiceData.isEmpty)
    }
    @MainActor func testVerseCorrectionCannotReportSuccessAfterAccountSwitch() async {
        let remote = ModerationProbe(), library = ModerationLibrary(remote: remote); library.select(UUID()); remote.suspendCorrection = true
        let task = Task { await library.feedback(recording, id: UUID(), comment: "Observation", verseID: 7) }
        while remote.correctionWaiting == nil { await Task.yield() }
        library.select(UUID()); remote.correctionWaiting?.resume()
        let sent = await task.value
        XCTAssertFalse(sent); XCTAssertNil(library.message); XCTAssertFalse(library.busy)
    }
    func testVerseVoiceFeedbackHidesOnlyRedundantEmptyGeneralAttachment() {
        let path = "feedback/\(UUID().uuidString)/test.m4a"
        func review(_ verse: Int?, _ comment: String?, _ voice: String?) -> RecitationFeedback {
            RecitationFeedback(id: UUID().uuidString, recitation_id: "recording", verse_id: verse, comment: comment, voice_path: voice, created_at: "2026-10-07T10:00:00Z", resolved_at: nil)
        }
        let precise = review(7, "Observation", path), empty = review(nil, nil, path), meaningful = review(nil, "Retour général", path), standalone = review(nil, nil, "feedback/\(UUID().uuidString)/another.m4a")
        let combined = RecitationFeedback.combining(general: [empty, meaningful, standalone], verses: [precise])
        XCTAssertEqual(Set(combined.map(\.id)), Set([precise.id, meaningful.id, standalone.id]))
    }
    @MainActor func testDeletionChangesOnlyAfterServerConfirmation() async {
        let remote = ModerationProbe()
        let subject = ModerationLibrary(remote: remote); subject.select(UUID()); await subject.load(.messages)
        remote.fail = true; await subject.moderate(subject.items[0], section: .messages)
        XCTAssertEqual(subject.items[0]["body"].string, "Original"); XCTAssertEqual(subject.items[0]["deleted_at"], .null)
        remote.fail = false; await subject.moderate(subject.items[0], section: .messages)
        XCTAssertNotEqual(subject.items[0]["deleted_at"], .null)
    }
    @MainActor func testAccountChangeRejectsLatePrivilegedRowsAndClearsMemory() async {
        let remote = ModerationProbe(); remote.hold = true
        let subject = ModerationLibrary(remote: remote); subject.select(UUID())
        let fetch = Task { await subject.load(.messages) }
        while remote.waiting == nil { await Task.yield() }
        subject.select(UUID()); remote.waiting?.resume(returning: remote.supplied); await fetch.value
        XCTAssertTrue(subject.items.isEmpty); XCTAssertNil(subject.playback.activeID); XCTAssertFalse(subject.loading)
    }
    @MainActor func testRevokedAccessClearsPrivilegedRows() async {
        let remote = ModerationProbe()
        let library = ModerationLibrary(remote: remote); library.select(UUID()); await library.load(.messages)
        XCTAssertEqual(library.items.count, 1)
        remote.fail = true; await library.load(.messages)
        XCTAssertTrue(library.items.isEmpty); XCTAssertNotNil(library.message)
    }
    @MainActor func testFeedbackRetryKeepsSameIdentityAndReportsFailure() async {
        let remote = ModerationProbe(), id = UUID(); let library = ModerationLibrary(remote: remote)
        library.select(UUID()); remote.fail = true
        let first = await library.feedback(remote.supplied[0], id: id, comment: "Retour")
        XCTAssertFalse(first)
        remote.fail = false
        let second = await library.feedback(remote.supplied[0], id: id, comment: "Retour")
        XCTAssertTrue(second); XCTAssertEqual(remote.feedbackIDs, [id, id])
    }
    @MainActor func testPrivateAudioPathRejectsTraversalAndOtherOwners() {
        let owner = UUID().uuidString.lowercased()
        let row: JSONValue = .object(["user_id": .string(owner), "storage_path": .string(owner + "/recording.m4a")])
        XCTAssertTrue(ModerationRepository.validAudioPath(row))
        for path in ["other/file.m4a", owner + "/../file.m4a", owner + "/%2e%2e/file.m4a", owner + "/"] {
            XCTAssertFalse(ModerationRepository.validAudioPath(row.setting("storage_path", .string(path))))
        }
    }
    @MainActor func testVoiceFeedbackRetryKeepsDraftAndRequestWithoutRequiringText() async throws {
        let remote = ModerationProbe(), id = UUID(), file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bytes = Data([1, 2, 3]); try bytes.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let library = ModerationLibrary(remote: remote); library.select(UUID())
        remote.fail = true
        let first = await library.feedback(remote.supplied[0], id: id, comment: "", voice: file)
        XCTAssertFalse(first); XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        remote.fail = false
        let second = await library.feedback(remote.supplied[0], id: id, comment: "", voice: file)
        XCTAssertTrue(second); XCTAssertEqual(remote.feedbackIDs, [id, id]); XCTAssertEqual(remote.voiceData, [bytes, bytes])
    }
    @MainActor func testEmptyVoiceFeedbackIsRejectedBeforeRemotePublication() async throws {
        let remote = ModerationProbe(), file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        let library = ModerationLibrary(remote: remote); library.select(UUID())
        let sent = await library.feedback(remote.supplied[0], id: UUID(), comment: "", voice: file)
        XCTAssertFalse(sent); XCTAssertTrue(remote.feedbackIDs.isEmpty)
    }
}
