import XCTest
@testable import CoranNative

final class RevisionScheduleTests: XCTestCase {
    let catalog = QuranCatalog()
    let zone = TimeZone(identifier: "Europe/Paris")!
    func state(_ ids: [Int]) -> JSONValue {
        .object(["knowledge": .object(Dictionary(uniqueKeysWithValues: ids.map { (String($0), JSONValue.string("perfect")) })), "unknown": .string("keep")])
    }
    func change(_ date: String, preferences: RevisionPreferences? = nil) throws -> RevisionScheduleChange {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: date))
        return RevisionScheduleChange(preferences: preferences, now: now, timeZone: zone)
    }
    func testWholeDivisionsAndWeightsPartitionWithoutLosingOrInventingVerses() {
        let ids = catalog.hizbs.prefix(7).flatMap { Array($0.start...$0.end) }
        let days = RevisionSchedule.temporal(ids, length: 14, catalog: catalog)
        let halves = RevisionSchedule.halves(catalog)
        XCTAssertEqual(days.count, 14)
        for day in 0..<14 { XCTAssertEqual(days[day], Array(halves[day].start...halves[day].end)) }
        let sparse = Array(Set((1...90).filter { $0 % 3 != 0 } + [6236]))
        for length in [7, 14, 21, 30] {
            let partitions = RevisionSchedule.temporal(sparse, length: length, catalog: catalog)
            XCTAssertEqual(partitions.count, length)
            XCTAssertEqual(partitions.flatMap { $0 }, sparse.sorted())
        }
    }
    func testQuantityUsesRealBoundariesAndKnownGapsOnly() {
        let known = Array(1...catalog.juzs[2].end).filter { $0 % 5 != 0 }
        for (kind, units) in [("nisf", RevisionSchedule.halves(catalog)), ("hizb", catalog.hizbs), ("juz", catalog.juzs)] {
            let days = RevisionSchedule.quantity(known, kind: kind, catalog: catalog)
            XCTAssertEqual(days.flatMap { $0 }, known)
            for (day, unit) in zip(days, units) { XCTAssertTrue(day.allSatisfy { unit.start <= $0 && $0 <= unit.end }) }
        }
        let pairs = RevisionSchedule.quantity(known, kind: "juz2", catalog: catalog)
        XCTAssertEqual(pairs.count, 2); XCTAssertEqual(pairs.flatMap { $0 }, known)
        XCTAssertEqual(pairs[0].last, known.last { $0 <= catalog.juzs[1].end })
    }
    func testMissedDaysKeepOriginalDatesAndOneSharePerDay() throws {
        let original = state(Array(1...7)).setting("reviewCycle", .object(["index": .number(1), "startDate": .string("2026-10-05"), "lengthDays": .number(7), "corpus": .array((1...7).map { .number(Double($0)) }), "days": .array((1...7).map { .array([.number(Double($0))]) }), "completed": .array([]), "assignments": .object([:])]))
        let operation = try change("2026-10-07T12:00:00Z")
        let next = operation.applying(to: original, catalog: catalog)
        XCTAssertEqual(next["reviewCycle"]["assignments"]["2026-10-07"].int, 0)
        XCTAssertEqual(next["reviewCycle"]["startDate"].string, "2026-10-05")
        let task = try XCTUnwrap(ProgramProjection(snapshot: HomeSnapshot(state: next), now: ISO8601DateFormatter().date(from: "2026-10-07T12:00:00Z")!, timeZone: zone).revision)
        XCTAssertEqual(task.scheduledDate, "2026-10-05"); XCTAssertEqual(task.range.count, 1)
        XCTAssertEqual(operation.applying(to: next, catalog: catalog), next)
    }
    func testRolloverArchivesCompletedCycleOnlyAfterItsEnd() throws {
        let monday = try change("2026-10-05T12:00:00Z")
        var next = monday.applying(to: state(Array(1...7)), catalog: catalog)
        next = next.setting("reviewCycle", next["reviewCycle"].setting("completed", next["reviewCycle"]["corpus"]))
        let before = try change("2026-10-11T12:00:00Z").applying(to: next, catalog: catalog)
        XCTAssertEqual(before["reviewCycle"]["index"].int, 1)
        let after = try change("2026-10-12T12:00:00Z").applying(to: before, catalog: catalog)
        XCTAssertEqual(after["reviewCycle"]["index"].int, 2)
        XCTAssertEqual(after["reviewCycleHistory"].array.count, 1)
        XCTAssertEqual(after["reviewCycleHistory"].array[0]["completed"], next["reviewCycle"]["corpus"])
        XCTAssertEqual(after["unknown"], next["unknown"])
    }
    func testNewLearningWaitsForJ7AndDoesNotAlterActiveCorpus() throws {
        var original = state([1, 2, 3]).setting("memorizedAt", .object(["2": .string("2026-10-04"), "3": .string("2026-10-04")]))
        original = original.setting("reviewConsolidations", .object(["3": .object(["learnedAt": .string("2026-10-04"), "completed": .object(["7": .string("2026-10-05")])])]))
        let next = try change("2026-10-05T12:00:00Z").applying(to: original, catalog: catalog)
        XCTAssertEqual(next["reviewCycle"]["corpus"].array.compactMap(\.int), [1, 3])
        let enlarged = next.setting("knowledge", next["knowledge"].setting("4", .string("perfect")))
        let later = try change("2026-10-06T12:00:00Z").applying(to: enlarged, catalog: catalog)
        XCTAssertEqual(later["reviewCycle"]["corpus"], next["reviewCycle"]["corpus"])
    }
    func testSettingsPersistReplayAndPausePreserveHistoryAndUnknownFields() throws {
        let original = try change("2026-10-05T12:00:00Z").applying(to: state(Array(1...7)), catalog: catalog)
            .setting("reviewSettings", .object(["adminField": .string("keep")]))
        var preferences = RevisionPreferences(state: original); preferences.mode = "quantity"; preferences.dailyQuantity = "nisf"
        var op = ReaderOperation(kind: .reviewSchedule, verseID: 1, page: 1, source: "")
        op.reviewSchedule = try change("2026-10-06T12:00:00Z", preferences: preferences)
        let decoded = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(op))
        let next = decoded.applying(to: original, catalog: catalog)
        XCTAssertEqual(next["reviewSettings"]["dailyQuantity"].string, "nisf")
        XCTAssertEqual(next["reviewSettings"]["adminField"].string, "keep")
        XCTAssertEqual(next["reviewCycleHistory"].array.count, 1)
        XCTAssertEqual(decoded.applying(to: next, catalog: catalog), next)
        preferences.enabled = false
        let paused = try change("2026-10-07T12:00:00Z", preferences: preferences).applying(to: next, catalog: catalog)
        XCTAssertEqual(paused["reviewCycle"], next["reviewCycle"])
        XCTAssertEqual(try change("2026-10-08T12:00:00Z").applying(to: paused, catalog: catalog), paused)
        XCTAssertEqual(decoded.applying(to: paused, catalog: catalog), paused)
        XCTAssertNil(ProgramProjection(snapshot: HomeSnapshot(state: paused)).revision)
    }
    func testLocalDayAcrossDSTAndEmptyAccountDoNotCreateSpuriousCycles() throws {
        let empty = state([])
        XCTAssertEqual(try change("2026-10-24T22:30:00Z").day, "2026-10-25")
        XCTAssertEqual(try change("2026-10-25T23:30:00Z").day, "2026-10-26")
        XCTAssertEqual(try change("2026-10-25T23:30:00Z").applying(to: empty, catalog: catalog), empty)
    }
    func testOfflineScheduleQueueSurvivesDiskAndReplayPreservesSingleArchive() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LocalStorageService(directory: directory), user = UUID()
        let original = try change("2026-10-05T12:00:00Z").applying(to: state(Array(1...100)), catalog: catalog)
        var preferences = RevisionPreferences(state: original); preferences.cycleDays = 14
        var operation = ReaderOperation(kind: .reviewSchedule, verseID: 1, page: 1, source: "")
        operation.reviewSchedule = try change("2026-10-06T12:00:00Z", preferences: preferences)
        var snapshot = HomeSnapshot(state: operation.applying(to: original, catalog: catalog))
        snapshot.readerOperations = [operation]
        try storage.save(snapshot, userID: user)
        let reopened = try XCTUnwrap(try storage.load(userID: user))
        let queued = try XCTUnwrap(reopened.readerOperations?.first)
        let synchronized = queued.applying(to: original, catalog: catalog)
        XCTAssertEqual(synchronized, reopened.state)
        XCTAssertEqual(queued.applying(to: synchronized, catalog: catalog), synchronized)
        XCTAssertEqual(synchronized["reviewCycleHistory"].array.count, 1)
        XCTAssertEqual(synchronized["reviewSettings"]["cycleDays"].int, 14)
    }
}
