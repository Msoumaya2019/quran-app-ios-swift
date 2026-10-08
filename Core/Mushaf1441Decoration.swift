import UIKit

/// Edition-specific coordinates exported from the original 1441 ayahinfo database.
/// Drawing these overlays never changes the fifteen line images or hit-testing regions.
enum Mushaf1441Decoration {
    static func headers(page: Int) throws -> [[Double]] {
        guard let url = Bundle.main.url(forResource: "coran_1441-headers", withExtension: "json") else {
            throw URLError(.fileDoesNotExist)
        }
        let rows = try JSONDecoder().decode([[Double]].self, from: Data(contentsOf: url))
        return rows.filter { $0.count == 5 && Int($0[1]) == page }
    }

    static func rect(_ row: [Double], imageSize: CGSize) -> CGRect {
        guard row.count == 5, imageSize.width > 0 else { return .zero }
        let pageWidth: CGFloat = 1440, pageHeight: CGFloat = 2320, lineHeight: CGFloat = 232
        let width = floor(pageWidth * 1038 / 1080)
        let height = floor(width * imageSize.height / imageSize.width)
        let centerY = (pageHeight - lineHeight) / 14 * CGFloat(row[2]) + CGFloat(row[4]) * lineHeight
        return CGRect(x: floor(CGFloat(row[3]) * pageWidth - width / 2),
                      y: floor(centerY - height / 2), width: width, height: height)
    }
}
