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
    func testSnapshotRequiresEveryPageAndPreservesPosition() throws {
        var records: [JSONValue] = [.object(["record_type": .string("mushaf"), "id": .number(19), "pages_count": .number(604)])]
        for page in 1...604 {
            records.append(.object(["record_type": .string("mushaf_word"), "id": .number(Double(page)), "mushaf_id": .number(19), "source_verse_id": .number(1), "page_number": .number(Double(page)), "line_number": .number(3), "position_in_verse": .number(1), "position_in_page": .number(1), "text": .string("ﱁ"), "char_type_name": .string("word")]))
        }
        func data(_ records: [JSONValue], version: Int = 1) throws -> Data {
            try JSONEncoder().encode(JSONValue.object(["resource_group": .string("mushafs"), "resource_id": .number(19), "schema_version": .number(Double(version)), "records": .array(records)]))
        }
        let pages = try TajweedMushafPage.decodeSnapshot(data(records))
        XCTAssertEqual(pages.count, 604)
        XCTAssertEqual(pages.last?.number, 604)
        XCTAssertEqual(pages[41].words.first?.line, 3)
        XCTAssertThrowsError(try TajweedMushafPage.decodeSnapshot(data(Array(records.dropLast()))))
        XCTAssertThrowsError(try TajweedMushafPage.decodeSnapshot(data(records, version: 2)))
        XCTAssertThrowsError(try TajweedMushafPage.decodeSnapshot(data(records + [records[1]])))
    }
}
