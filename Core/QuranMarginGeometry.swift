import Foundation

struct QuranVerseRegion: Equatable {
    let id: Int
    let ayah: Int
    let line: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
struct QuranMarginMarker: Equatable {
    let ids: [Int]
    let numbers: [Int]
    let y: Double
    let bottom: Double
    let completed: Bool
    let difficult: Bool
    let inSession: Bool
    var label: String {
        if numbers.count > 1, numbers.last! - numbers.first! == numbers.count - 1 { return "\(numbers.first!)–\(numbers.last!)" }
        return numbers.map(String.init).joined(separator: "·")
    }
}
enum QuranMarginGeometry {
    static let medinaRows: [String: [[Double]]] = {
        guard let url = Bundle.main.url(forResource: "medina-bounds", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: [[Double]]].self, from: data)) ?? [:]
    }()
    static func regions(source: QuranSource, page: Int, catalog: QuranCatalog) -> [QuranVerseRegion] {
        let rows = source == .edition1441 ? QuranSourceMapping.rows1441[String(page)] : medinaRows[String(page)]
        let width: Double = source == .edition1441 ? 1440 : 1920
        let height: Double = source == .edition1441 ? 2320 : 3106
        return (rows ?? []).compactMap { row in
            guard row.count >= 7, let surah = catalog.surahs.first(where: { $0.number == Int(row[0]) }),
                  row[4] > row[3], row[6] > row[5] else { return nil }
            let id = surah.start + Int(row[1]) - 1
            guard id <= surah.end else { return nil }
            return QuranVerseRegion(id: id, ayah: Int(row[1]), line: Int(row[2]), x: row[3] / width, y: row[5] / height, width: (row[4] - row[3]) / width, height: (row[6] - row[5]) / height)
        }
    }
    static func imageRect(image: CGSize, viewport: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, viewport.width > 0, viewport.height > 0 else { return .zero }
        let scale = min(viewport.width / image.width, viewport.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (viewport.width - size.width) / 2, y: (viewport.height - size.height) / 2, width: size.width, height: size.height)
    }
    static func markers(regions: [QuranVerseRegion], range: VerseRange?, through: Int, difficultIDs: Set<Int>) -> [QuranMarginMarker] {
        var anchors: [Int: QuranVerseRegion] = [:]
        for region in regions where difficultIDs.contains(region.id) || range.map({ ($0.start...$0.end).contains(region.id) }) == true {
            if let old = anchors[region.id], old.line < region.line || old.line == region.line && old.y <= region.y { continue }
            anchors[region.id] = region
        }
        let groups = Dictionary(grouping: anchors.values, by: \.line)
        return groups.values.map { group in
            let sorted = group.sorted { $0.id < $1.id }, ids = sorted.map(\.id)
            let y = group.map { $0.y + $0.height * 0.35 }.min() ?? 0
            let bottom = regions.filter { ids.contains($0.id) }.map { $0.y + $0.height }.max() ?? y
            let sessionIDs = ids.filter { id in range.map { ($0.start...$0.end).contains(id) } == true }
            return QuranMarginMarker(ids: ids, numbers: sorted.map(\.ayah), y: y, bottom: bottom, completed: !sessionIDs.isEmpty && sessionIDs.allSatisfy { $0 <= through }, difficult: ids.contains { difficultIDs.contains($0) }, inSession: !sessionIDs.isEmpty)
        }.sorted { $0.y < $1.y }
    }
}
