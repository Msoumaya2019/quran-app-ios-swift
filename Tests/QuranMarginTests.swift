import XCTest
import UIKit
@testable import CoranNative

final class QuranMarginTests: XCTestCase {
    private func range(_ a: Int, _ b: Int) throws -> VerseRange {
        try XCTUnwrap(VerseRange(json: .object(["start": .number(Double(a)), "end": .number(Double(b))])))
    }
    func testOriginalBoundsCoverAllVersesForBothSources() {
        let catalog = QuranCatalog()
        for source in QuranSource.available {
            let regions = (1...604).flatMap { QuranMarginGeometry.regions(source: source, page: $0, catalog: catalog) }
            XCTAssertEqual(Set(regions.map(\.id)), Set(1...6236))
            XCTAssertTrue(regions.allSatisfy { $0.x >= 0 && $0.y >= 0 && $0.width > 0 && $0.height > 0 })
        }
    }
    func testStartsAreGroupedByLineAndMultilineVerseUsesFirstAnchor() throws {
        let rows = [QuranVerseRegion(id: 1, ayah: 1, line: 1, x: 0.5, y: 0.1, width: 0.4, height: 0.1), QuranVerseRegion(id: 2, ayah: 2, line: 1, x: 0.1, y: 0.1, width: 0.4, height: 0.1), QuranVerseRegion(id: 2, ayah: 2, line: 2, x: 0.5, y: 0.2, width: 0.4, height: 0.1)]
        let markers = QuranMarginGeometry.markers(regions: rows, range: try range(1, 2), through: 1, difficultIDs: [2])
        XCTAssertEqual(markers.count, 1); XCTAssertEqual(markers[0].label, "1–2")
        XCTAssertEqual(markers[0].y, 0.135, accuracy: 0.001); XCTAssertEqual(markers[0].bottom, 0.3, accuracy: 0.001)
        XCTAssertFalse(markers[0].completed); XCTAssertTrue(markers[0].difficult)
    }
    func testMultiPageRangeAndSingleVerseRemainRestrictedToDisplayedPage() throws {
        let catalog = QuranCatalog(), sessionRange = try range(1, 12)
        for page in 1...3 {
            let rows = QuranMarginGeometry.regions(source: .medina, page: page, catalog: catalog)
            let markers = QuranMarginGeometry.markers(regions: rows, range: sessionRange, through: 7, difficultIDs: [])
            XCTAssertTrue(markers.flatMap(\.ids).allSatisfy { id in (1...12).contains(id) && rows.contains(where: { $0.id == id }) })
        }
        let rows = QuranMarginGeometry.regions(source: .medina, page: 1, catalog: catalog)
        let single = QuranMarginGeometry.markers(regions: rows, range: try self.range(6, 6), through: 6, difficultIDs: [])
        XCTAssertEqual(single.count, 1); XCTAssertEqual(single[0].ids, [6]); XCTAssertTrue(single[0].completed)
    }
    func testAspectFitCenterAndRatioAcrossPortraitLandscapeAndSmallViewport() {
        for image in [CGSize(width: 1920, height: 3106), CGSize(width: 1440, height: 2320)] {
            for viewport in [CGSize(width: 430, height: 780), CGSize(width: 320, height: 480), CGSize(width: 780, height: 320)] {
                let rect = QuranMarginGeometry.imageRect(image: image, viewport: viewport)
                XCTAssertEqual(rect.midX, viewport.width / 2, accuracy: 0.001)
                XCTAssertEqual(rect.midY, viewport.height / 2, accuracy: 0.001)
                XCTAssertEqual(rect.width / rect.height, image.width / image.height, accuracy: 0.001)
                XCTAssertLessThanOrEqual(rect.width, viewport.width + 0.001); XCTAssertLessThanOrEqual(rect.height, viewport.height + 0.001)
            }
        }
    }
    @MainActor func testOverlayCannotMoveImageOrInterceptTapsAndStaysBeforeGlyphs() throws {
        let controller = PageController(page: 1, onTap: {})
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 430, height: 780)
        let size = CGSize(width: 1920, height: 3106)
        controller.set(image: UIGraphicsImageRenderer(size: size).image { _ in })
        controller.view.layoutIfNeeded()
        let image = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIImageView }.first), before = image.frame
        controller.set(annotations: QuranPageAnnotations(range: try range(1, 7), through: 3, difficultIDs: [6], color: .systemGreen))
        controller.view.layoutIfNeeded()
        XCTAssertEqual(image.frame, before)
        let overlay = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? QuranMarginOverlay }.first)
        overlay.layoutIfNeeded(); XCTAssertFalse(overlay.isUserInteractionEnabled)
        XCTAssertNil(overlay.hitTest(CGPoint(x: 10, y: 10), with: nil))
        let rect = QuranMarginGeometry.imageRect(image: size, viewport: before.size)
        let rows = QuranMarginGeometry.regions(source: .medina, page: 1, catalog: QuranCatalog())
        let textEdge = rect.minX + CGFloat(try XCTUnwrap(rows.map(\.x).min())) * rect.width
        XCTAssertFalse(overlay.subviews.isEmpty)
        for marker in overlay.subviews { XCTAssertLessThan(marker.frame.maxX, textEdge); XCTAssertGreaterThanOrEqual(marker.frame.minX, 0) }
    }
}
