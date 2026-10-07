import XCTest
@testable import CoranNative

private actor AudioDownloadProbe {
    private(set) var count = 0
    func data() async throws -> Data {
        count += 1
        try await Task.sleep(nanoseconds: 50_000_000)
        return Data([1, 2, 3, 4])
    }
}

final class QuranAudioTests: XCTestCase {
    func testSimultaneousRequestsDownloadOnceAndReopenOffline() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let probe = AudioDownloadProbe()
        let cache = QuranAudioCache(directory: directory, downloader: { _ in try await probe.data() })
        async let first = cache.file(reciterID: "ar.husary", verseID: 1)
        async let second = cache.file(reciterID: "ar.husary", verseID: 1)
        let files = try await (first, second)
        XCTAssertEqual(files.0, files.1)
        let count = await probe.count
        XCTAssertEqual(count, 1)
        let offlineCache = QuranAudioCache(directory: directory, downloader: { _ in throw URLError(.notConnectedToInternet) })
        let offlineFile = try await offlineCache.file(reciterID: "ar.husary", verseID: 1)
        XCTAssertEqual(try Data(contentsOf: offlineFile), Data([1, 2, 3, 4]))
    }
    func testEmptyDownloadIsNotCommittedAndCanRetry() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = QuranAudioCache(directory: directory, downloader: { _ in Data() })
        do { _ = try await cache.file(reciterID: "ar.alafasy", verseID: 2); XCTFail("An empty audio file must be rejected") } catch {}
        let retry = QuranAudioCache(directory: directory, downloader: { _ in Data([9]) })
        let file = try await retry.file(reciterID: "ar.alafasy", verseID: 2)
        XCTAssertEqual(try Data(contentsOf: file), Data([9]))
    }
    func testReciterOperationPreservesOtherAudioPreferencesAndReplays() throws {
        let state: JSONValue = .object(["audioPreferences": .object(["reciterId": .string("ar.shaatree"), "futureOption": .bool(true)]), "reader": .object(["mushaf": .string("traditional")])])
        let operation = ReaderOperation(kind: .reciter, verseID: 1, page: 1, source: "ar.husary")
        let decoded = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(operation))
        let updated = decoded.applying(to: state, catalog: QuranCatalog())
        XCTAssertEqual(updated["audioPreferences"]["reciterId"].string, "ar.husary")
        XCTAssertEqual(updated["audioPreferences"]["futureOption"], state["audioPreferences"]["futureOption"])
        XCTAssertEqual(updated["reader"], state["reader"])
        XCTAssertEqual(decoded.applying(to: updated, catalog: QuranCatalog()), updated)
    }
    @MainActor func testLocalPlaybackTimelineSeekPauseAndResume() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wave = Self.silentWave()
        let cache = QuranAudioCache(directory: directory, downloader: { _ in wave })
        let audio = QuranAudioService(cache: cache)
        audio.play(1)
        let ready = await waitUntil { audio.timeline.duration > 0 || audio.error != nil }
        XCTAssertTrue(ready)
        XCTAssertNil(audio.error)
        guard audio.timeline.duration > 0 else { audio.pause(); return }
        XCTAssertEqual(audio.timeline.duration, 3, accuracy: 0.1)
        audio.seek(to: 1)
        try await Task.sleep(nanoseconds: 250_000_000)
        let beforeChange = audio.timeline.elapsed
        var live = audio.repeatSettings; live.speed = 0.85; live.count = 3; live.gap = 1; live.recitePause = 5
        audio.configure(live)
        XCTAssertTrue(audio.playing); XCTAssertFalse(audio.loading)
        XCTAssertEqual(audio.verseID, 1); XCTAssertGreaterThanOrEqual(audio.timeline.elapsed, beforeChange - 0.05)
        XCTAssertEqual(audio.repeatSettings.count, 3)
        audio.pause()
        XCTAssertFalse(audio.playing)
        XCTAssertGreaterThanOrEqual(audio.timeline.elapsed, 0.8)
        audio.toggle(start: 1)
        XCTAssertTrue(audio.playing)
        audio.pause()
        audio.changeReciter("ar.husary")
        XCTAssertEqual(audio.reciterID, "ar.husary")
        XCTAssertEqual(audio.timeline.duration, 0)
        audio.changeReciter("invalid")
        XCTAssertEqual(audio.reciterID, "ar.husary")
    }
    @MainActor func testNonFiniteTimelineIsSafe() {
        let timeline = QuranAudioTimeline()
        timeline.update(elapsed: .nan, duration: .infinity)
        XCTAssertEqual(timeline.elapsed, 0); XCTAssertEqual(timeline.duration, 0)
        XCTAssertEqual(QuranAudioTimeline.timeLabel(.nan), "0:00")
        XCTAssertEqual(QuranAudioTimeline.timeLabel(65), "1:05")
    }
    @MainActor func testEndOfRecitationAdvancesCurrentAyahAutomatically() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wave = Self.silentWave()
        let audio = QuranAudioService(cache: QuranAudioCache(directory: directory, downloader: { _ in wave }))
        defer { audio.pause() }
        audio.play(1)
        let ready = await waitUntil { audio.timeline.duration > 0 || audio.error != nil }
        XCTAssertTrue(ready); XCTAssertNil(audio.error)
        guard audio.timeline.duration > 0 else { return }
        audio.seek(to: 2.6)
        let advanced = await waitUntil { audio.verseID == 2 || audio.error != nil }
        XCTAssertTrue(advanced); XCTAssertEqual(audio.verseID, 2); XCTAssertNil(audio.error)
    }
    @MainActor func testVerseRepeatsThenAdvancesAndStopsAtSelectedEnd() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wave = Self.silentWave()
        let audio = QuranAudioService(cache: QuranAudioCache(directory: directory, downloader: { _ in wave }))
        defer { audio.pause() }
        var settings = AudioRepeatSettings(); settings.count = 2
        audio.start(range: 1...2, settings: settings)
        let reached1 = await waitUntil { audio.timeline.duration > 0 || audio.error != nil }
        XCTAssertTrue(reached1)
        audio.seek(to: 2.6)
        let reached2 = await waitUntil { audio.repetition == 2 || audio.error != nil }
        XCTAssertTrue(reached2)
        XCTAssertEqual(audio.verseID, 1); XCTAssertEqual(audio.repetition, 2)
        audio.seek(to: 2.6)
        let reached3 = await waitUntil { audio.verseID == 2 && audio.timeline.duration > 0 || audio.error != nil }
        XCTAssertTrue(reached3)
        XCTAssertEqual(audio.repetition, 1)
        audio.seek(to: 2.6)
        let reached4 = await waitUntil { audio.repetition == 2 || audio.error != nil }
        XCTAssertTrue(reached4)
        audio.seek(to: 2.6)
        let reached5 = await waitUntil { !audio.playing }
        XCTAssertTrue(reached5)
        XCTAssertEqual(audio.verseID, 2); XCTAssertNil(audio.error)
    }
    @MainActor func testPauseCancelsDelayedRepeatAndResumeRetainsPendingRepetition() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let wave = Self.silentWave()
        let audio = QuranAudioService(cache: QuranAudioCache(directory: directory, downloader: { _ in wave }))
        defer { audio.pause() }
        var settings = AudioRepeatSettings(); settings.count = 2; settings.gap = 2
        audio.start(range: 1...1, settings: settings)
        let reached6 = await waitUntil { audio.timeline.duration > 0 || audio.error != nil }
        XCTAssertTrue(reached6)
        audio.seek(to: 2.6)
        try await Task.sleep(nanoseconds: 900_000_000)
        audio.pause()
        try await Task.sleep(nanoseconds: 2_100_000_000)
        XCTAssertFalse(audio.playing); XCTAssertEqual(audio.repetition, 1)
        audio.toggle(start: 1)
        let reached7 = await waitUntil { audio.repetition == 2 || audio.error != nil }
        XCTAssertTrue(reached7)
        XCTAssertTrue(audio.playing); XCTAssertEqual(audio.verseID, 1); XCTAssertNil(audio.error)
    }
    @MainActor private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 { if condition() { return true }; try? await Task.sleep(nanoseconds: 50_000_000) }
        return condition()
    }
    private static func silentWave() -> Data {
        let samples = Data(repeating: 0, count: 8_000 * 2 * 3)
        var data = Data("RIFF".utf8)
        func integer<T: FixedWidthInteger>(_ value: T) { var little = value.littleEndian; withUnsafeBytes(of: &little) { data.append(contentsOf: $0) } }
        integer(UInt32(36 + samples.count)); data.append(Data("WAVEfmt ".utf8))
        integer(UInt32(16)); integer(UInt16(1)); integer(UInt16(1)); integer(UInt32(8_000))
        integer(UInt32(16_000)); integer(UInt16(2)); integer(UInt16(16))
        data.append(Data("data".utf8)); integer(UInt32(samples.count)); data.append(samples)
        return data
    }
}
