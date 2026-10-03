import XCTest
@testable import CoranNative

final class ReaderTests: XCTestCase {
    func testReaderOperationPreservesUnknownFieldsAndTombstones() throws {
        let catalog = QuranCatalog()
        let original: JSONValue = .object(["schema": .number(1), "future": .object(["value": .string("preserved")]), "bookmarks": .object([:])])
        let add = ReaderOperation(kind: .bookmark, verseID: 3371, page: 397, source: "coran_1441", date: Date(timeIntervalSince1970: 100))
        let added = add.applying(to: original, catalog: catalog)
        XCTAssertEqual(added["future"], original["future"])
        XCTAssertEqual(added["bookmarks"]["3371"]["sourcePages"]["coran_1441"].int, 397)
        let remove = ReaderOperation(kind: .removeBookmark, verseID: 3371, page: 400, source: "traditional", date: Date(timeIntervalSince1970: 200))
        let removed = remove.applying(to: added, catalog: catalog)
        XCTAssertNotNil(removed["bookmarks"]["3371"]["deletedAt"].string)
        XCTAssertEqual(add.applying(to: removed, catalog: catalog), removed)
        XCTAssertEqual(remove.applying(to: removed, catalog: catalog), removed)
    }
    func testLegacySnapshotWithoutQueueStillDecodes() throws {
        let data = Data(#"{"state":{},"contents":[],"quizAvailable":false,"quizDone":false}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(HomeSnapshot.self, from: data).readerOperations)
    }
    func testTwentyMedinaPagesKeepBoundedCache() async throws {
        let cache = QuranPageCache()
        for page in 1...21 {
            await cache.prepare(source: .medina, page: page)
            let image = try await cache.image(source: .medina, page: page)
            XCTAssertGreaterThan(image.size.width, 0)
            let count = await cache.cachedPageCount
            XCTAssertLessThanOrEqual(count, 3)
        }
        for page in stride(from: 20, through: 15, by: -1) { await cache.prepare(source: .medina, page: page) }
        let hits = await cache.hits
        XCTAssertGreaterThan(hits, 20)
        let times = await cache.renderMilliseconds
        print("[ReaderMetrics] Medina render ms: \(times); cache hits: \(hits); decoded page count: \(await cache.cachedPageCount); decoded image bytes: \(await cache.decodedBytes)")
    }
    func testSourcePageBounds() {
        for source in QuranSource.available { XCTAssertEqual(source.validPage(0), 1); XCTAssertEqual(source.validPage(605), 604) }
    }
    func testTwenty1441PagesOfflineKeepOriginalRatioAndBoundedCache() async throws {
        let root = try XCTUnwrap(Bundle.main.resourceURL).appendingPathComponent("ReaderTestFixtures")
        let cache = QuranPageCache(lineRoot: root)
        for page in 1...21 {
            await cache.prepare(source: .edition1441, page: page)
            let image = try await cache.image(source: .edition1441, page: page)
            XCTAssertEqual(image.size.width, 1440); XCTAssertEqual(image.size.height, 2320)
            let count = await cache.cachedPageCount
            XCTAssertLessThanOrEqual(count, 3)
        }
        for page in stride(from: 20, through: 17, by: -1) { await cache.prepare(source: .edition1441, page: page) }
        print("[ReaderMetrics] 1441 render ms: \(await cache.renderMilliseconds); decoded page count: \(await cache.cachedPageCount); decoded image bytes: \(await cache.decodedBytes)")
    }
    func test1441MappingUsesOriginalCoordinatesRatherThanCanonicalPagination() {
        let catalog = QuranCatalog()
        let id = QuranSourceMapping.firstVerse(source: .edition1441, page: 397, catalog: catalog)
        XCTAssertEqual(catalog.surah(for: id)?.number, 29)
        XCTAssertEqual(id - (catalog.surah(for: id)?.start ?? 1) + 1, 7)
        let page = QuranSourceMapping.page(source: .edition1441, verseID: id, catalog: catalog)
        XCTAssertTrue(QuranSourceMapping.verseIDs(page: page, catalog: catalog).contains(id))
    }
}
