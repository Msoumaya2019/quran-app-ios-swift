import XCTest
@testable import CoranNative

final class TajweedMushafTests: XCTestCase {
    private func response(next: String = "null", line: Int = 3, glyph: String = "ﱁ") -> Data {
        Data("""
        {"verses":[{"verse_key":"2:1","words":[{"position":1,"page_number":42,"line_number":\(line),"code_v2":"\(glyph)","char_type_name":"word"}]}],"pagination":{"next_page":\(next)}}
        """.utf8)
    }
    func testPreservesOriginalGlyphAndLine() throws {
        let page = try TajweedMushafPage.decodeAPI(response(), page: 42)
        XCTAssertEqual(page.words.first?.line, 3)
        XCTAssertEqual(page.words.first?.glyph, "ﱁ")
        XCTAssertEqual(page.words.first?.verseKey, "2:1")
    }
    func testRejectsTruncatedAndInvalidPages() {
        XCTAssertThrowsError(try TajweedMushafPage.decodeAPI(response(next: "2"), page: 42))
        XCTAssertThrowsError(try TajweedMushafPage.decodeAPI(response(line: 16), page: 42))
        XCTAssertThrowsError(try TajweedMushafPage.decodeAPI(response(), page: 605))
        XCTAssertThrowsError(try TajweedMushafPage.decodeAPI(response(glyph: "<script>"), page: 42))
    }
    func testLocalRendererCannotFetchRemoteContent() throws {
        let html = try TajweedMushafHTML.document(TajweedMushafPage.decodeAPI(response(), page: 42))
        XCTAssertTrue(html.contains("connect-src 'none'"))
        XCTAssertTrue(html.contains("flex-wrap:nowrap"))
        XCTAssertTrue(html.contains("verseKey"))
        XCTAssertFalse(html.contains("https://"))
    }
}
