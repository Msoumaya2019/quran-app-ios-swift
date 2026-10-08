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
    /// Documented Content Sync schema v1. Never creates an offline dump from online verse calls.
    static func decodeSnapshot(_ data: Data) throws -> [Self] {
        let envelope = try JSONDecoder().decode(JSONValue.self, from: data)
        guard envelope["resource_group"].string == "mushafs", envelope["resource_id"].int == 19,
              envelope["schema_version"].int == 1 else { throw URLError(.cannotParseResponse) }
        let records = envelope["records"].array
        guard records.contains(where: { $0["record_type"].string == "mushaf" && $0["id"].int == 19 && $0["pages_count"].int == 604 }) else { throw URLError(.cannotParseResponse) }
        let catalog = QuranCatalog()
        var rows: [Int: [(Int, Word)]] = [:]
        var seen = Set<Int>()
        for record in records where record["record_type"].string == "mushaf_word" {
            guard record["mushaf_id"].int == 19, let id = record["id"].int, seen.insert(id).inserted,
                  let verseID = record["source_verse_id"].int, let surah = catalog.surah(for: verseID), verseID >= surah.start, verseID <= surah.end,
                  let page = record["page_number"].int, (1...604).contains(page),
                  let line = record["line_number"].int, (1...15).contains(line),
                  let position = record["position_in_verse"].int, position > 0,
                  let order = record["position_in_page"].int, order > 0,
                  let glyph = record["text"].string, !glyph.isEmpty,
                  glyph.unicodeScalars.allSatisfy({ (0xF000...0xFFFF).contains(Int($0.value)) || $0.value == 32 }) else { throw URLError(.cannotParseResponse) }
            let word = Word(verseKey: "\(surah.number):\(verseID - surah.start + 1)", position: position, line: line, glyph: glyph, end: record["char_type_name"].string == "end")
            rows[page, default: []].append((order, word))
        }
        return try (1...604).map { number in
            let positioned = (rows[number] ?? []).sorted { $0.0 < $1.0 }
            guard !positioned.isEmpty, Set(positioned.map { $0.0 }).count == positioned.count else { throw URLError(.cannotParseResponse) }
            let words = positioned.map { $0.1 }
            guard zip(words, words.dropFirst()).allSatisfy({ $0.0.line <= $0.1.line }) else { throw URLError(.cannotParseResponse) }
            return Self(number: number, words: words)
        }
    }
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
