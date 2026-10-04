import XCTest
@testable import CoranNative

final class QuranIndexTests: XCTestCase {
    func testOriginalDivisionsCoverEntireQuranWithoutGaps() {
        let catalog = QuranCatalog()
        XCTAssertEqual(catalog.surahs.count, 114)
        XCTAssertEqual(catalog.juzs.count, 30)
        XCTAssertEqual(catalog.hizbs.count, 60)
        for divisions in [catalog.juzs, catalog.hizbs] {
            XCTAssertEqual(divisions.first?.start, 1)
            XCTAssertEqual(divisions.last?.end, 6236)
            for (left, right) in zip(divisions, divisions.dropFirst()) { XCTAssertEqual(left.end + 1, right.start) }
        }
        XCTAssertEqual(catalog.surahs.first?.isMeccan, true)
    }
    func testDivisionNavigationUsesOriginalSourceMapping() {
        let catalog = QuranCatalog()
        for source in QuranSource.available {
            let pages = (catalog.juzs + catalog.hizbs).map { QuranSourceMapping.page(source: source, verseID: $0.start, catalog: catalog) }
            XCTAssertTrue(pages.allSatisfy { (1...604).contains($0) })
            XCTAssertEqual(pages.first, 1)
        }
        XCTAssertEqual(catalog.page(for: catalog.juzs[1].start), 22)
    }
}
