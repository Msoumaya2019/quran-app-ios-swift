import Foundation

/// QCF V4 uses code_v2 codepoints, with Mushaf 19's own word positions.
struct TajweedMushafPage: Codable, Sendable {
    static let version = "qcf-v4-mushaf-19-1"
    struct Word: Codable, Sendable {
        let verseKey: String
        let position: Int
        let line: Int
        let glyph: String
        let end: Bool
    }
    let number: Int
    let words: [Word]
    var verseKeys: Set<String> { Set(words.map(\.verseKey)) }
    static func verseID(_ key: String, catalog: QuranCatalog) -> Int? {
        let parts = key.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, let surah = catalog.surahs.first(where: { $0.number == parts[0] }), parts[1] > 0,
              surah.start + parts[1] - 1 <= surah.end else { return nil }
        return surah.start + parts[1] - 1
    }
    static func decodeAPI(_ data: Data, page: Int) throws -> Self {
        struct Response: Decodable {
            struct Verse: Decodable {
                struct Word: Decodable {
                    let position: Int
                    let page_number: Int
                    let line_number: Int
                    let code_v2: String
                    let char_type_name: String
                }
                let verse_key: String
                let words: [Word]
            }
            struct Pagination: Decodable { let next_page: Int? }
            let verses: [Verse]
            let pagination: Pagination
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        // Never silently install a truncated page or words from an adjacent page.
        guard response.pagination.next_page == nil, (1...604).contains(page) else { throw URLError(.cannotParseResponse) }
        let catalog = QuranCatalog()
        var words: [Word] = []
        for verse in response.verses {
            guard verseID(verse.verse_key, catalog: catalog) != nil else { throw URLError(.cannotParseResponse) }
            for word in verse.words where word.page_number == page {
                guard (1...15).contains(word.line_number), word.position > 0, !word.code_v2.isEmpty,
                      word.code_v2.unicodeScalars.allSatisfy({ (0xF000...0xFFFF).contains(Int($0.value)) || $0.value == 32 }) else { throw URLError(.cannotParseResponse) }
                words.append(Word(verseKey: verse.verse_key, position: word.position, line: word.line_number, glyph: word.code_v2, end: word.char_type_name == "end"))
            }
        }
        guard !words.isEmpty, zip(words, words.dropFirst()).allSatisfy({ pair in pair.0.line <= pair.1.line }) else { throw URLError(.cannotParseResponse) }
        return Self(number: page, words: words)
    }
}
