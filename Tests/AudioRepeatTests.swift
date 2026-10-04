import XCTest
@testable import CoranNative

final class AudioRepeatTests: XCTestCase {
    func testEachVerseRepeatsBeforeAdvancingAndStopsAtEnd() {
        var settings = AudioRepeatSettings(); settings.count = 3
        var position = AudioRepeatSettings.Position(verse: 10, repetition: 1)
        var sequence = [position.verse]
        while let next = settings.next(range: 10...12, current: position) { sequence.append(next.verse); position = next }
        XCTAssertEqual(sequence, [10,10,10,11,11,11,12,12,12])
    }
    func testPassageRepeatsWholeRangeAndContinuousModes() {
        var settings = AudioRepeatSettings(); settings.mode = .passage; settings.count = 2
        var position = AudioRepeatSettings.Position(verse: 10, repetition: 1)
        var sequence = [position.verse]
        while let next = settings.next(range: 10...12, current: position) { sequence.append(next.verse); position = next }
        XCTAssertEqual(sequence, [10,11,12,10,11,12])
        settings.count = 0
        XCTAssertEqual(settings.next(range: 10...12, current: .init(verse: 12, repetition: 99)), .init(verse: 10, repetition: 100))
        settings.mode = .eachVerse
        XCTAssertEqual(settings.next(range: 10...12, current: .init(verse: 11, repetition: 99)), .init(verse: 11, repetition: 100))
        settings.count = 1; settings.autoStop = false
        XCTAssertEqual(settings.next(range: 10...12, current: .init(verse: 12, repetition: 1)), .init(verse: 10, repetition: 1))
    }
    func testPreferencePersistenceReplaysAndRetainsReciterAndUnknownFields() throws {
        let state: JSONValue = .object(["audioPreferences": .object(["reciterId": .string("ar.husary"), "futureOption": .bool(true)])])
        var settings = AudioRepeatSettings(); settings.count = 5; settings.gap = 2; settings.speed = 0.75
        var operation = ReaderOperation(kind: .audioRepeat, verseID: 1, page: 1, source: "")
        operation.audioRepeat = settings
        let restored = try JSONDecoder().decode(ReaderOperation.self, from: JSONEncoder().encode(operation))
        let updated = restored.applying(to: state, catalog: QuranCatalog())
        XCTAssertEqual(AudioRepeatSettings.load(updated), settings)
        XCTAssertEqual(updated["audioPreferences"]["reciterId"].string, "ar.husary")
        XCTAssertEqual(updated["audioPreferences"]["futureOption"].bool, true)
        XCTAssertEqual(restored.applying(to: updated, catalog: QuranCatalog()), updated)
        let old = settings.applying(to: updated, at: "2000-01-01T00:00:00Z")
        XCTAssertEqual(old, updated)
    }
    func testInvalidPreferencesAndPositionsAreRejected() {
        var settings = AudioRepeatSettings(); settings.count = 1000
        XCTAssertFalse(settings.valid); XCTAssertNil(settings.next(range: 1...2, current: .init(verse: 1, repetition: 1)))
        settings.count = 1
        XCTAssertNil(settings.next(range: 1...2, current: .init(verse: 3, repetition: 1)))
        settings.gap = -1; XCTAssertFalse(settings.valid)
        XCTAssertEqual(AudioRepeatSettings.load(.null), AudioRepeatSettings())
    }
}
