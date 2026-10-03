import UIKit
import ImageIO

actor QuranPageCache {
    static let shared = QuranPageCache()
    private struct Key: Hashable { let source: String; let page: Int }
    private var images: [Key: UIImage] = [:]
    private var pending: [Key: Task<UIImage, Error>] = [:]
    private var retained: Set<Key> = []
    private(set) var hits = 0
    private(set) var renders = 0
    func prepare(source: QuranSource, page: Int) async {
        retained = Set((max(1, page - 1)...min(source.pageCount, page + 1)).map { Key(source: source.id, page: $0) })
        images = images.filter { retained.contains($0.key) }
        for number in [page, page - 1, page + 1] where (1...source.pageCount).contains(number) {
            _ = try? await image(source: source, page: number)
        }
    }
    func image(source: QuranSource, page: Int) async throws -> UIImage {
        let key = Key(source: source.id, page: page)
        if let image = images[key] { hits += 1; return image }
        if let task = pending[key] { return try await task.value }
        let task = Task.detached(priority: .userInitiated) { try Self.render(source: source, page: page) }
        pending[key] = task
        defer { pending[key] = nil }
        let image = try await task.value
        renders += 1
        if retained.contains(key) { images[key] = image }
        return image
    }
    func clear() { images.removeAll(); retained.removeAll() }
    var cachedPageCount: Int { images.count }
    private nonisolated static func render(source: QuranSource, page: Int) throws -> UIImage {
        switch source.renderingType {
        case .pageImage:
            guard let root = Bundle.main.resourceURL,
                  let image = UIImage(contentsOfFile: root.appendingPathComponent("Medina/page\(String(format: "%03d", page)).png").path),
                  let decoded = image.preparingForDisplay() else { throw URLError(.fileDoesNotExist) }
            return decoded
        case .lineImages:
            let width: CGFloat = 1440, height: CGFloat = 2320, lineHeight: CGFloat = 232
            let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
            var lines: [UIImage] = []
            for line in 1...15 {
                guard let image = UIImage(contentsOfFile: QuranResourceService.shared.lineURL(page: page, line: line).path) else { throw URLError(.fileDoesNotExist) }
                lines.append(image)
            }
            let markerURL = Bundle.main.url(forResource: "coran_1441-markers", withExtension: "json")!
            let markers = try JSONDecoder().decode([String: [[Double]]].self, from: Data(contentsOf: markerURL))[String(page)] ?? []
            return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
                UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                for (index, image) in lines.enumerated() {
                    image.draw(in: CGRect(x: 0, y: (height - lineHeight) / 14 * CGFloat(index), width: width, height: lineHeight))
                }
                for marker in markers where marker.count >= 5 {
                    let diameter = width * 0.05
                    let y = (height - lineHeight) / 14 * CGFloat(marker[2]) + CGFloat(marker[4]) * lineHeight
                    let rect = CGRect(x: CGFloat(marker[3]) * width - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
                    let circle = UIBezierPath(ovalIn: rect)
                    UIColor(red: 0.925, green: 0.992, blue: 0.961, alpha: 1).setFill(); circle.fill()
                    UIColor(red: 0.016, green: 0.471, blue: 0.341, alpha: 1).setStroke(); circle.lineWidth = width * 0.003; circle.stroke()
                    let text = String(Int(marker[1])).map { "٠١٢٣٤٥٦٧٨٩".map(String.init)[Int(String($0))!] }.joined()
                    let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: width * 0.025), .foregroundColor: UIColor(red: 0.016, green: 0.471, blue: 0.341, alpha: 1)]
                    let size = (text as NSString).size(withAttributes: attributes)
                    (text as NSString).draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
                }
            }
        }
    }
}
