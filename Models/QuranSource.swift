import Foundation

enum ReadingMode: String, Codable { case classic, learning, revision, consolidation }
struct QuranSource: Identifiable, Equatable, Sendable {
    enum Rendering: Equatable, Sendable { case pageImage, lineImages, tajweedQCF }
    let id: String
    let displayName: String
    let pageCount: Int
    let renderingType: Rendering
    let resourceLocation: String
    let supportsAyahMapping: Bool
    let supportsTajwid: Bool
    let supportsAudioSync: Bool
    static let medina = QuranSource(id: "traditional", displayName: "Coran de Médine", pageCount: 604, renderingType: .pageImage, resourceLocation: "Medina", supportsAyahMapping: true, supportsTajwid: false, supportsAudioSync: true)
    static let edition1441 = QuranSource(id: "coran_1441", displayName: "Coran 1441", pageCount: 604, renderingType: .lineImages, resourceLocation: "coran_1441", supportsAyahMapping: true, supportsTajwid: false, supportsAudioSync: true)
    static let tajweed = QuranSource(id: "qcf_tajweed_v4", displayName: "Coran Tajweed", pageCount: 604, renderingType: .tajweedQCF, resourceLocation: "qcf_tajweed_v4", supportsAyahMapping: true, supportsTajwid: true, supportsAudioSync: true)
    static let available = [medina, edition1441, tajweed]
    func validPage(_ page: Int) -> Int { min(pageCount, max(1, page)) }
}

enum QuranSourceMapping {
    static let rows1441: [String: [[Double]]] = {
        guard let url = Bundle.main.url(forResource: "coran_1441-bounds", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [[Double]]].self, from: data)) ?? [:]
    }()
    static func verseIDs(page: Int, catalog: QuranCatalog) -> [Int] {
        (rows1441[String(page)] ?? []).compactMap { row in
            guard row.count >= 2, let surah = catalog.surahs.first(where: { $0.number == Int(row[0]) }) else { return nil }
            return surah.start + Int(row[1]) - 1
        }
    }
    static func firstVerse(source: QuranSource, page: Int, catalog: QuranCatalog) -> Int {
        if source == .edition1441 { return verseIDs(page: page, catalog: catalog).min() ?? 1 }
        return catalog.pageStarts.first { $0.0 == page }?.1 ?? 1
    }
    static func page(source: QuranSource, verseID: Int, catalog: QuranCatalog) -> Int {
        if source == .edition1441 { return (1...604).first { verseIDs(page: $0, catalog: catalog).contains(verseID) } ?? 1 }
        return catalog.page(for: verseID)
    }
}
