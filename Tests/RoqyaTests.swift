import XCTest
@testable import CoranNative

@MainActor final class RoqyaTests: XCTestCase {
    func testMediaURLRejectsInsecureAndCredentialURLs() {
        XCTAssertNil(RoqyaLibrary.validMediaURL("http://example.com/a.mp3"))
        XCTAssertNil(RoqyaLibrary.validMediaURL("https://user:secret@example.com/a.mp3"))
        XCTAssertNil(RoqyaLibrary.validMediaURL("file:///a.mp3"))
        XCTAssertNotNil(RoqyaLibrary.validMediaURL("https://example.com/a.mp3"))
    }
    func testCatalogueFiltersDisabledAudioAndReciter() {
        let valid: JSONValue = .object(["enabled": .bool(true), "audio_url": .string("https://example.com/a.mp3"), "roqya_reciters": .object(["enabled": .bool(true)])])
        let row: JSONValue = .object(["roqya_audios": .array([valid, valid.setting("enabled", .bool(false)), valid.setting("roqya_reciters", .object(["enabled": .bool(false)]))])])
        XCTAssertEqual(RoqyaLibrary.audios(row).count, 1)
    }
    func testFavoriteIsPersistedAndNeverLeaksToAnotherAccount() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let a = UUID(), b = UUID(), library = RoqyaLibrary(client: nil, directory: root)
        library.select(a); library.toggleFavorite("one")
        library.select(b); XCTAssertTrue(library.favorites.isEmpty)
        let reopened = RoqyaLibrary(client: nil, directory: root)
        reopened.select(a); XCTAssertEqual(reopened.favorites, ["one"])
        reopened.select(nil); XCTAssertTrue(reopened.favorites.isEmpty)
    }
    func testIncompleteOrChangedDownloadIsNotInstalled() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased(), file = root.appendingPathComponent(id + ".m4a")
        let audio: JSONValue = .object(["id": .string(id), "storage_path": .string("test/a.m4a"), "file_size": .number(3)])
        try Data([1, 2, 3]).write(to: file)
        let library = RoqyaLibrary(client: nil, directory: root)
        XCTAssertNil(library.localFile(audio))
        try JSONEncoder().encode(JSONValue.object(["source": .string("test/a.m4a:3"), "size": .number(3)])).write(to: file.appendingPathExtension("json"))
        XCTAssertEqual(library.localFile(audio), file)
        XCTAssertNil(library.localFile(audio.setting("file_size", .number(4))))
        try Data([1]).write(to: file); XCTAssertNil(library.localFile(audio))
    }
    func testPendingAudioIsInvalidatedWhenAnotherPlayerTakesFocus() {
        let playback = RecitationPlaybackService(), other = UUID()
        var invalidated = false
        playback.reserveFocus { invalidated = true }
        NativeAudioFocus.shared.claim(other) {}
        XCTAssertTrue(invalidated)
        NativeAudioFocus.shared.release(other)
    }
    func testAudioFocusOnlyInterruptsPreviousOwner() {
        let focus = NativeAudioFocus(), first = UUID(), second = UUID()
        var interrupted = 0
        focus.claim(first) { interrupted += 1 }
        focus.claim(first) { interrupted += 1 }; XCTAssertEqual(interrupted, 0)
        focus.claim(second) {}; XCTAssertEqual(interrupted, 1)
        focus.release(first); focus.claim(second) {}; XCTAssertEqual(interrupted, 1)
    }
    func testAudioAdminRequiresRoqyaReciterDurationAndSafePath() {
        let row: JSONValue = .object(["sort_order": .number(0), "enabled": .bool(true), "roqya_id": .string(UUID().uuidString), "reciter_id": .string(UUID().uuidString), "duration_seconds": .number(60), "storage_path": .string("user/audio.mp3")])
        XCTAssertTrue(RoqyaLibrary.validAdminRow(table: "roqya_audios", row: row))
        XCTAssertFalse(RoqyaLibrary.validAdminRow(table: "roqya_audios", row: row.setting("storage_path", .string("../bad.mp3"))))
        XCTAssertFalse(RoqyaLibrary.validAdminRow(table: "roqya_audios", row: row.setting("duration_seconds", .number(0))))
    }
}
