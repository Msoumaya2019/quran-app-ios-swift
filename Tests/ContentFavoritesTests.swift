import XCTest
@testable import CoranNative

@MainActor private final class ContentFavoritesProbe: ContentFavoritesRemote {
    var fail = true
    var loseAcknowledgement = false
    var hold = false
    var waiting: CheckedContinuation<Void, Never>?
    var changes: [ContentFavoriteChange] = []
    var ids: Set<String> = []
    var contents: [DailyContent] = []
    func load(owner: UUID) async throws -> ContentFavoritesCache {
        if fail { throw URLError(.notConnectedToInternet) }
        var value = ContentFavoritesCache(owner: owner); value.ids = Array(ids); value.contents = contents.filter { ids.contains($0.id) }; return value
    }
    func set(owner: UUID, change: ContentFavoriteChange) async throws {
        if fail { throw URLError(.notConnectedToInternet) }
        if hold { hold = false; await withCheckedContinuation { waiting = $0 } }
        changes.append(change)
        if change.enabled { ids.insert(change.contentID) } else { ids.remove(change.contentID) }
        if loseAcknowledgement { loseAcknowledgement = false; throw URLError(.networkConnectionLost) }
    }
}
final class ContentFavoritesTests: XCTestCase {
    private func content() throws -> DailyContent {
        let row: JSONValue = .object(["id": .string(UUID().uuidString), "type": .string("invocation"), "french_text": .string("Texte technique"), "source": .string("Source technique")])
        return try JSONDecoder().decode(DailyContent.self, from: JSONEncoder().encode(row))
    }
    @MainActor func testOfflineFavoriteSurvivesRestartAndSynchronizesAfterLostAcknowledgement() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let remote = ContentFavoritesProbe(), owner = UUID(), item = try content()
        remote.contents = [item]
        let library = ContentFavoritesLibrary(remote: remote, directory: directory); library.select(owner); library.toggle(item)
        await library.synchronize()
        XCTAssertTrue(library.contains(item.id)); XCTAssertEqual(library.cache?.pending.count, 1)
        let reopened = ContentFavoritesLibrary(remote: remote, directory: directory); reopened.select(owner)
        XCTAssertTrue(reopened.contains(item.id)); XCTAssertEqual(reopened.cache?.contents.first?.id, item.id)
        remote.fail = false; remote.loseAcknowledgement = true
        await reopened.synchronize(); XCTAssertEqual(reopened.cache?.pending.count, 1)
        await reopened.synchronize(); XCTAssertEqual(reopened.cache?.pending.count, 0)
        XCTAssertEqual(remote.ids.count, 1); XCTAssertEqual(Set(remote.changes.map(\.id)).count, 1)
        XCTAssertNil(item.audio_url)
    }
    @MainActor func testRemovingWhileAddIsInFlightKeepsLatestIntent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let remote = ContentFavoritesProbe(), item = try content(); remote.fail = false; remote.hold = true; remote.contents = [item]
        let library = ContentFavoritesLibrary(remote: remote, directory: directory); library.select(UUID()); library.toggle(item)
        let sync = Task { await library.synchronize() }
        while remote.waiting == nil { await Task.yield() }
        library.toggle(item); XCTAssertFalse(library.contains(item.id))
        remote.waiting?.resume(); remote.waiting = nil; await sync.value
        XCTAssertFalse(library.contains(item.id)); XCTAssertTrue(remote.ids.isEmpty); XCTAssertEqual(library.cache?.pending.count, 0)
        XCTAssertEqual(remote.changes.map(\.enabled), [true, false])
    }
    @MainActor func testAccountChangeDoesNotDisplayPreviousFavoritesAfterDelayedSync() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let remote = ContentFavoritesProbe(), item = try content(); remote.fail = false; remote.hold = true
        let first = UUID(), second = UUID(), library = ContentFavoritesLibrary(remote: remote, directory: directory)
        library.select(first); library.toggle(item)
        let sync = Task { await library.synchronize() }
        while remote.waiting == nil { await Task.yield() }
        library.select(second); remote.waiting?.resume(); remote.waiting = nil; await sync.value
        XCTAssertEqual(library.cache?.owner, second); XCTAssertTrue(library.cache?.ids.isEmpty == true)
        library.select(first); XCTAssertTrue(library.contains(item.id)); XCTAssertEqual(library.cache?.pending.count, 1)
    }
}
