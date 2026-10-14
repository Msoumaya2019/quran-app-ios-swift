import XCTest
import UIKit
import SwiftUI
@testable import CoranNative

final class NativeImprovementsTests: XCTestCase {
    func testAll1441MarkersUseCanonicalNumbersIncludingPage600() throws {
        let file = try XCTUnwrap(Bundle.main.url(forResource: "coran_1441-markers", withExtension: "json"))
        let pages = try JSONDecoder().decode([String: [[Double]]].self, from: Data(contentsOf: file))
        let catalog = QuranCatalog()
        var seen = Set<String>()
        for markers in pages.values { for m in markers {
            let chapter = try XCTUnwrap(catalog.surahs.first { $0.number == Int(m[0]) })
            let ayah = Int(m[1]); XCTAssertTrue((1...chapter.count).contains(ayah))
            XCTAssertTrue(seen.insert("\(chapter.number):\(ayah)").inserted)
            let encoded = MushafVerseNumber.text(ayah).unicodeScalars.map { Int($0.value - 0x0660) }
            XCTAssertEqual(encoded.map(String.init).joined(), String(ayah))
        } }
        XCTAssertEqual(seen.count, 6236)
        XCTAssertEqual(pages["600"]?.filter { $0[0] == 101 }.map { Int($0[1]) }, Array(1...11))
        XCTAssertEqual(pages["600"]?.filter { $0[0] == 102 }.map { Int($0[1]) }, Array(1...8))
        XCTAssertEqual(MushafVerseNumber.text(255), "\u{0662}\u{0665}\u{0665}")
    }
    func testForegroundMeterDoesNotCountBackgroundOrCatchUpAfterSuspension() {
        var meter = ForegroundUsageMeter()
        XCTAssertEqual(meter.checkpoint(uptime: 10), 0)
        meter.resume(uptime: 100)
        XCTAssertEqual(meter.checkpoint(uptime: 110), 10)
        meter.pause()
        XCTAssertEqual(meter.checkpoint(uptime: 1000), 0)
        meter.resume(uptime: 1000)
        XCTAssertEqual(meter.checkpoint(uptime: 1005), 5)
        XCTAssertEqual(meter.checkpoint(uptime: 2000), 10)
        XCTAssertEqual(meter.checkpoint(uptime: 2001), 1)
    }
    func testNightImagesPreserveGeometryAndSaturatedColors() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let input = UIGraphicsImageRenderer(size: CGSize(width: 3, height: 1), format: format).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0,y: 0,width: 1,height: 1))
            UIColor.black.setFill(); ctx.fill(CGRect(x: 1,y: 0,width: 1,height: 1))
            UIColor.green.setFill(); ctx.fill(CGRect(x: 2,y: 0,width: 1,height: 1))
        }
        let output = MushafNightImage.render(input)
        XCTAssertEqual(output.size, input.size)
        let cg = try XCTUnwrap(output.cgImage)
        var bytes = [UInt8](repeating: 0, count: 12)
        let context = try XCTUnwrap(CGContext(data: &bytes,width: 3,height: 1,bitsPerComponent: 8,bytesPerRow: 12,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(cg,in: CGRect(x: 0,y: 0,width: 3,height: 1))
        XCTAssertLessThan(bytes[0], 30); XCTAssertGreaterThan(bytes[4], 220)
        XCTAssertEqual(Array(bytes[8...10]), [0,255,0])
    }
    func testNightImagePreservesTransparentAntialiasing() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 2,height: 1),format: format).image { ctx in
            UIColor.black.withAlphaComponent(0.5).setFill(); ctx.fill(CGRect(x: 1,y: 0,width: 1,height: 1))
        }
        let result = MushafNightImage.render(image)
        let cg = try XCTUnwrap(result.cgImage)
        var pixels = [UInt8](repeating: 0,count: 8)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress,width: 2,height: 1,bitsPerComponent: 8,bytesPerRow: 8,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(cg,in: CGRect(x: 0,y: 0,width: 2,height: 1))
        }
        XCTAssertEqual(pixels[3],0); XCTAssertEqual(pixels[0],0)
        XCTAssertEqual(Double(pixels[7]),128,accuracy: 1)
        XCTAssertGreaterThan(pixels[4],100); XCTAssertLessThanOrEqual(pixels[4],pixels[7])
    }
    func testActualMedinaAnd1441PagesInBothAppearances() async throws {
        let fixtures = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("ReaderTestFixtures"))
        let cache = QuranPageCache(lineRoot: fixtures)
        for source in [QuranSource.medina, .edition1441] { for page in [1,42,600] {
            let light = try await cache.image(source: source,page: page)
            let dark = MushafNightImage.render(light, greenMarkers: source == .edition1441)
            XCTAssertEqual(dark.size,light.size)
            for (name,image) in [("light",light),("dark",dark)] {
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(source.id)-page-\(page)-\(name)"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        } }
    }
    @MainActor func testPreloadedPageHasNightTraitsBeforeEnteringPager() {
        let page = PageController(page: 600, source: .medina, night: true, onTap: {})
        page.loadViewIfNeeded()
        XCTAssertEqual(page.traitCollection.userInterfaceStyle,.dark)
        XCTAssertEqual(page.view.backgroundColor,MushafNightImage.paper)
        page.setNightMode(false)
        XCTAssertEqual(page.traitCollection.userInterfaceStyle,.light)
        XCTAssertEqual(page.view.backgroundColor,.white)
    }
    @MainActor func testAppearancePersistsAndUsesReadableDarkAccent() {
        let theme = ThemeManager(), old = theme.appearance
        defer { theme.appearance = old }
        theme.appearance = "dark"
        XCTAssertEqual(ThemeManager().preferredScheme, .dark)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let foreground = UIColor(theme.text).resolvedColor(with: dark)
        var r: CGFloat=0,g: CGFloat=0,b: CGFloat=0,a: CGFloat=0
        foreground.getRed(&r,green: &g,blue: &b,alpha: &a)
        XCTAssertGreaterThan(r, 0.8)
    }
}
