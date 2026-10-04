import UIKit

struct QuranPageAnnotations: Equatable {
    var range: VerseRange? = nil
    var through = 0
    var difficultIDs: Set<Int> = []
    var color: UIColor = .systemGreen
    var audioVerseID: Int? = nil
    var audioColor: UIColor = .systemGreen
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.range == rhs.range && lhs.through == rhs.through && lhs.difficultIDs == rhs.difficultIDs && lhs.color.isEqual(rhs.color)
            && lhs.audioVerseID == rhs.audioVerseID && lhs.audioColor.isEqual(rhs.audioColor)
    }
}

// This layer never participates in the image layout or handles touches.
final class QuranMarginOverlay: UIView {
    private let rail = CAShapeLayer()
    private var regions: [QuranVerseRegion] = []
    private var markers: [QuranMarginMarker] = []
    private var imageSize = CGSize.zero
    private var annotations = QuranPageAnnotations()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(rail)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic overlay") }
    func configure(regions: [QuranVerseRegion], annotations: QuranPageAnnotations, imageSize: CGSize) {
        guard self.regions != regions || self.annotations != annotations || self.imageSize != imageSize else { return }
        self.regions = regions; self.annotations = annotations; self.imageSize = imageSize
        markers = QuranMarginGeometry.markers(regions: regions, range: annotations.range, through: annotations.through, difficultIDs: annotations.difficultIDs)
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.forEach { $0.removeFromSuperview() }; rail.path = nil
        let rect = QuranMarginGeometry.imageRect(image: imageSize, viewport: bounds.size)
        guard rect.width > 0, !markers.isEmpty, let minX = regions.map(\.x).min() else { return }
        // Use only real blank space to the left of all glyph bounding boxes.
        // On narrow margins the badge becomes a dot rather than covering text.
        let textEdge = rect.minX + CGFloat(minX) * rect.width
        let diameter = min(CGFloat(24), textEdge - 5)
        guard diameter >= 2 else { return }
        let left = textEdge - diameter - 3, center = left + diameter / 2
        let session = markers.filter(\.inSession)
        if let first = session.first, let last = session.last {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: center, y: rect.minY + CGFloat(first.y) * rect.height))
            path.addLine(to: CGPoint(x: center, y: rect.minY + CGFloat(last.bottom) * rect.height))
            rail.path = path.cgPath; rail.lineWidth = 1; rail.strokeColor = annotations.color.withAlphaComponent(0.3).cgColor
        }
        for marker in markers {
            let badge = UILabel()
            let color = marker.difficult ? UIColor.systemRed : annotations.color
            let size = diameter >= 16 ? diameter : min(5, diameter)
            badge.frame = CGRect(x: center - size / 2, y: rect.minY + CGFloat(marker.y) * rect.height - size / 2, width: size, height: size)
            badge.text = diameter >= 16 ? marker.label : nil
            badge.textAlignment = .center
            badge.font = .systemFont(ofSize: marker.numbers.count > 1 ? 9 : 11, weight: .medium)
            badge.adjustsFontSizeToFitWidth = true; badge.minimumScaleFactor = 0.75
            badge.layer.cornerRadius = size / 2; badge.clipsToBounds = true
            badge.layer.borderWidth = 0.8; badge.layer.borderColor = color.withAlphaComponent(0.75).cgColor
            badge.backgroundColor = marker.completed || diameter < 16 ? color : .white
            badge.textColor = marker.completed ? .white : color
            badge.isAccessibilityElement = true
            badge.accessibilityIdentifier = "quran.margin.\(marker.ids.first ?? 0)"
            badge.accessibilityLabel = "Verset \(marker.label)" + (marker.completed ? " validé" : "") + (marker.difficult ? " difficile" : "")
            addSubview(badge)
        }
    }
}
