import XCTest
@testable import CoranNative

final class VerseStudyTests: XCTestCase {
    func testSingleVerseLearningReusesKnowledgeAndConsolidationsAndReplays() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let change = VerseStudyChange(verseID: 255, action: .learned, now: now)
        let original: JSONValue = .object(["unknown": .string("keep")])
        let result = change.applying(to: original)
        XCTAssertEqual(result["knowledge"]["255"].string, "perfect")
        XCTAssertEqual(result["knowledge"]["254"], .null)
        XCTAssertEqual(result["memorizedAt"]["255"].string, "2026-10-05")
        XCTAssertEqual(result["reviewConsolidations"]["255"]["scheduledDates"]["3"].string, "2026-10-08")
        XCTAssertEqual(change.applying(to: result), result)
        XCTAssertEqual(result["unknown"].string, "keep")
        var snapshot = HomeSnapshot(); snapshot.state = result
        XCTAssertEqual(HomeProjection(snapshot: snapshot, now: now, timeZone: .current).weeklyVerseCounts.reduce(0, +), 1)
    }
    func testManualRevisionIsIndependentOfDifficultyAndRequiresKnownVerse() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z"))
        let change = VerseStudyChange(verseID: 2, action: .nextRevision, now: now)
        XCTAssertEqual(change.applying(to: .null), .null)
        let known: JSONValue = .object(["knowledge": .object(["2": .string("perfect")])])
        let result = change.applying(to: known)
        XCTAssertFalse(DifficultyChange.isDifficult(result, verseID: 2))
        var snapshot = HomeSnapshot(); snapshot.state = result
        let tasks = ReviewQueueProjection(program: ProgramProjection(snapshot: snapshot, now: now, timeZone: .current)).tasks
        let task = try XCTUnwrap(tasks.first { $0.revisionCategory == "priority" })
        XCTAssertEqual(task.range.start, 2)
        let validation = try XCTUnwrap(RevisionValidation(context: task, through: 2, grade: .perfect, state: result, source: .medina, catalog: QuranCatalog(), now: now.addingTimeInterval(60)))
        let completed = validation.applying(to: result)
        XCTAssertEqual(completed["nativeManualReviewDue"]["2"], .null)
        XCTAssertFalse(DifficultyChange.isDifficult(completed, verseID: 2))
    }
    func testNewAudioValuesAndLegacyDecoding() throws {
        let legacy = Data("{\"mode\":\"each-verse\",\"count\":2,\"gap\":0,\"speed\":1,\"autoStop\":true}".utf8)
        var settings = try JSONDecoder().decode(AudioRepeatSettings.self, from: legacy)
        XCTAssertEqual(settings.ending, .stop)
        settings.gap = 3; settings.speed = 0.85; settings.recitePause = 15; settings.after = .nextVerse
        XCTAssertTrue(settings.valid)
        XCTAssertEqual(settings.next(range: 2...2, current: .init(verse: 2, repetition: 2)), .init(verse: 3, repetition: 1))
        settings.after = .continuous
        XCTAssertNil(settings.next(range: 6236...6236, current: .init(verse: 6236, repetition: 2)))
    }
    @MainActor func testDownloadProgressUsesActualBytesAndUnknownLengthIsIndeterminate() {
        let status = QuranDownloadStatus()
        status.written = 42; status.expected = 61
        XCTAssertEqual(status.progress ?? 0, 42.0 / 61, accuracy: 0.00001)
        status.expected = -1; XCTAssertNil(status.progress)
        status.expected = 40; XCTAssertEqual(status.progress, 1)
    }
}
