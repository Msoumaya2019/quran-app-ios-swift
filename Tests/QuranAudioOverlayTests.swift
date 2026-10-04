import XCTest
import UIKit
@testable import CoranNative

@MainActor final class QuranAudioOverlayTests: XCTestCase {
    func testOnlyCurrentAyahFragmentsAreHighlightedAndTouchesPassThrough() throws {
        let catalog = QuranCatalog()
        for source in QuranSource.available {
            let regions = QuranMarginGeometry.regions(source: source, page: 1, catalog: catalog)
            let view = QuranAudioOverlay(frame: CGRect(x: 0, y: 0, width: 430, height: 700))
            let size = source == .medina ? CGSize(width: 1920, height: 3106) : CGSize(width: 1440, height: 2320)
            view.configure(regions: regions, imageSize: size, verseID: 1, color: .systemGreen); view.layoutIfNeeded()
            XCTAssertEqual(view.highlightRects.count, regions.filter { $0.id == 1 }.count)
            XCTAssertFalse(view.highlightRects.isEmpty)
            let first = view.highlightRects
            view.configure(regions: regions, imageSize: size, verseID: 2, color: .systemGreen); view.layoutIfNeeded()
            XCTAssertEqual(view.highlightRects.count, regions.filter { $0.id == 2 }.count)
            XCTAssertNotEqual(view.highlightRects, first)
            XCTAssertEqual(view.accessibilityValue, "2")
            XCTAssertFalse(view.isUserInteractionEnabled); XCTAssertNil(view.hitTest(CGPoint(x: 200, y: 300), with: nil))
            view.configure(regions: regions, imageSize: size, verseID: 6236, color: .systemGreen); view.layoutIfNeeded()
            XCTAssertTrue(view.highlightRects.isEmpty); XCTAssertTrue(view.isHidden)
        }
    }
    func testAudioAnnotationsDoNotMoveOrReplaceMushafAndClearWithoutAudio() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1920, height: 3106)).image { $0.cgContext.setFillColor(UIColor.white.cgColor); $0.cgContext.fill(CGRect(x: 0, y: 0, width: 1920, height: 3106)) }
        let controller = PageController(page: 1, onTap: {})
        controller.set(image: image); controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 560); controller.view.layoutIfNeeded()
        let mushaf = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIImageView }.first)
        let frame = mushaf.frame
        controller.set(annotations: QuranPageAnnotations(audioVerseID: 3)); controller.view.layoutIfNeeded()
        let overlay = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? QuranAudioOverlay }.first)
        XCTAssertFalse(overlay.highlightRects.isEmpty)
        XCTAssertTrue(mushaf.image === image); XCTAssertEqual(mushaf.frame, frame)
        controller.set(annotations: QuranPageAnnotations()); controller.view.layoutIfNeeded()
        XCTAssertTrue(overlay.highlightRects.isEmpty); XCTAssertTrue(overlay.isHidden)
        XCTAssertTrue(mushaf.image === image); XCTAssertEqual(mushaf.frame, frame)
    }
}
