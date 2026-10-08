import XCTest
import WebKit
@testable import CoranNative

final class TajweedDecorationTests: XCTestCase {
    func testCompanionFontsAreAvailableOfflineAndRepairCorruptedCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let directory = root.appendingPathComponent("page")
        defer { try? FileManager.default.removeItem(at: root) }
        try TajweedDecorationResources.prepare(in: directory)
        for name in TajweedDecorationResources.fingerprints.keys {
            let url = root.appendingPathComponent("common").appendingPathComponent(name)
            let original = try Data(contentsOf: url)
            XCTAssertGreaterThan(original.count, 1000)
            // Atomic replacement does not mutate a linked bundle font.
            try Data("incomplete".utf8).write(to: url, options: .atomic)
            try TajweedDecorationResources.prepare(in: directory)
            XCTAssertEqual(try Data(contentsOf: url), original)
        }
    }

    @MainActor func testWebKitDecorationsPreserveWordGeometryAndVerseSelection() async throws {
        let cases: [(Int, [TajweedMushafPage.Word], [Int], [Int])] = [
            (1, [.init(verseKey: "1:1", position: 1, line: 2, glyph: "ﱁ", end: false)], [1], []),
            (2, [.init(verseKey: "2:1", position: 1, line: 3, glyph: "ﱁ", end: false)], [1], [2]),
            (187, [.init(verseKey: "9:1", position: 1, line: 2, glyph: "ﱁ", end: false)], [1], []),
            (600, [.init(verseKey: "101:1", position: 1, line: 6, glyph: "ﱁ", end: false),
                   .init(verseKey: "102:1", position: 1, line: 13, glyph: "ﱂ", end: false)], [4, 11], [5, 12])
        ]
        for (number, words, titleLines, basmalaLines) in cases {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let directory = root.appendingPathComponent("page")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            try TajweedDecorationResources.prepare(in: directory)
            let fixtures = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("ReaderTestFixtures"))
            let font = try Data(contentsOf: fixtures.appendingPathComponent("qcf-p\(number).woff2"))
            try font.write(to: directory.appendingPathComponent("page.woff2"))
            try Data(contentsOf: fixtures.appendingPathComponent("qcf-p1.woff2")).write(to: directory.appendingPathComponent("basmala.woff2"))
            let html = try TajweedMushafHTML.document(.init(number: number, words: words))
            let file = directory.appendingPathComponent("page.html")
            try Data(html.utf8).write(to: file)
            let bridge = DecorationBridge(ready: expectation(description: "Local fonts and ornaments page \(number)"))
            let config = WKWebViewConfiguration()
            config.userContentController.add(bridge, name: "mushaf")
            let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1360), configuration: config)
            defer { web.stopLoading(); config.userContentController.removeScriptMessageHandler(forName: "mushaf") }
            web.loadFileURL(file, allowingReadAccessTo: root)
            await fulfillment(of: [bridge.ready], timeout: 20)
            XCTAssertNil(bridge.error)
            let result = try await web.evaluateJavaScript("""
            (()=>{const regions=()=>[...document.querySelectorAll('.word')].map(e=>{const r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height]});
              const before=regions();for(const e of document.querySelectorAll('.title'))e.style.display='none';const after=regions();
              for(const e of document.querySelectorAll('.title'))e.style.display='flex';
              const titles=[...document.querySelectorAll('.title')].map(e=>Number(e.dataset.line));
              const basmalas=[...document.querySelectorAll('.basmala')].map(e=>Number(e.dataset.line));
              const inks=[...document.querySelectorAll('.frame')].map(c=>c.getContext('2d').getImageData(0,0,c.width,c.height).data.some((v,i)=>i%4===3&&v>0));
              const e=document.querySelector('.word'),r=e.getBoundingClientRect();window.selectAt(r.x+r.width/2,r.y+r.height/2);
              return {before,after,titles,basmalas,inks};})()
            """) as? [String: Any]
            let info = try XCTUnwrap(result)
            XCTAssertEqual(info["titles"] as? [Int], titleLines)
            XCTAssertEqual(info["basmalas"] as? [Int], basmalaLines)
            XCTAssertEqual(info["before"] as? [[Double]], info["after"] as? [[Double]])
            XCTAssertEqual(info["inks"] as? [Bool], Array(repeating: true, count: titleLines.count))
            // Script-message delivery is asynchronous; yield before checking the existing verse bridge.
            for _ in 0..<20 where bridge.verse == nil { try await Task.sleep(for: .milliseconds(25)) }
            XCTAssertEqual(bridge.verse, words.first?.verseKey)
        }
    }
}

@MainActor private final class DecorationBridge: NSObject, WKScriptMessageHandler {
    let ready: XCTestExpectation
    var error: String?
    var verse: String?
    init(ready: XCTestExpectation) { self.ready = ready }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let value = message.body as? [String: Any], let kind = value["kind"] as? String else { return }
        if kind == "ready" { ready.fulfill() }
        if kind == "error" { error = value["value"] as? String; ready.fulfill() }
        if kind == "verse" { verse = value["value"] as? String }
    }
}
