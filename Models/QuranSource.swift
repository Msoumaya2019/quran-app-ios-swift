import Foundation

enum ReadingMode: String, Codable { case classic, learning, revision, consolidation }
struct QuranSource: Identifiable, Equatable, Sendable {
    enum Rendering: Sendable { case pageImage, lineImages }
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
    static let available = [medina, edition1441]
    func validPage(_ page: Int) -> Int { min(pageCount, max(1, page)) }
}
