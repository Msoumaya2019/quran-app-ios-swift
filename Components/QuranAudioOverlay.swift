import UIKit

/// Only the currently recited ayah is tinted. Session markings remain in the margin.
final class QuranAudioOverlay: UIView {
    private let highlight = CAShapeLayer()
    private var regions: [QuranVerseRegion] = []
    private var imageSize = CGSize.zero
    private var verseID: Int?
    private var color = UIColor.systemGreen
    private(set) var highlightRects: [CGRect] = []
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false; backgroundColor = .clear
        accessibilityIdentifier = "quran.audio.highlight"
        layer.addSublayer(highlight)
    }
    required init?(coder: NSCoder) { fatalError("Programmatic audio overlay") }
    func configure(regions: [QuranVerseRegion], imageSize: CGSize, verseID: Int?, color: UIColor) {
        guard self.regions != regions || self.imageSize != imageSize || self.verseID != verseID || !self.color.isEqual(color) else { return }
        self.regions = regions; self.imageSize = imageSize; self.verseID = verseID; self.color = color
        setNeedsLayout()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        let image = QuranMarginGeometry.imageRect(image: imageSize, viewport: bounds.size)
        highlightRects = image.width > 0 ? regions.filter { $0.id == verseID }.map {
            CGRect(x: image.minX + CGFloat($0.x) * image.width, y: image.minY + CGFloat($0.y) * image.height,
                   width: CGFloat($0.width) * image.width, height: CGFloat($0.height) * image.height)
        } : []
        let path = UIBezierPath()
        for rect in highlightRects { path.append(UIBezierPath(roundedRect: rect, cornerRadius: 3)) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        highlight.path = path.cgPath; highlight.fillColor = color.withAlphaComponent(0.12).cgColor
        CATransaction.commit()
        isAccessibilityElement = !highlightRects.isEmpty
        accessibilityValue = verseID.map(String.init)
        accessibilityLabel = "Verset en cours de récitation"
        isHidden = highlightRects.isEmpty
    }
}
