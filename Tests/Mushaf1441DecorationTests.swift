import XCTest
import UIKit
@testable import CoranNative

final class Mushaf1441DecorationTests: XCTestCase {
    func testOriginalHeaderPositionsIncludingMultipleSurahs() throws {
        XCTAssertEqual(try Mushaf1441Decoration.headers(page: 1).map { Int($0[0]) }, [1])
        XCTAssertEqual(try Mushaf1441Decoration.headers(page: 2).map { Int($0[0]) }, [2])
        let middle = try Mushaf1441Decoration.headers(page: 600)
        XCTAssertEqual(middle.map { Int($0[0]) }, [101, 102])
        XCTAssertEqual(middle.map { Int($0[2]) }, [3, 10])
        XCTAssertEqual(try Mushaf1441Decoration.headers(page: 187).map { Int($0[0]) }, [9])
        XCTAssertTrue(try Mushaf1441Decoration.headers(page: 42).isEmpty)
    }

    func testEveryDecorationUsesOriginalCoordinatesAndFitsPage() throws {
        let size = CGSize(width: 3420, height: 360)
        var count = 0
        for page in 1...604 {
            for row in try Mushaf1441Decoration.headers(page: page) {
                count += 1
                let rect = Mushaf1441Decoration.rect(row, imageSize: size)
                XCTAssertEqual(rect.midX, 720, accuracy: 1)
                XCTAssertEqual(rect.midY, CGFloat((2320.0 - 232.0) / 14.0 * row[2] + row[4] * 232.0), accuracy: 1)
                XCTAssertGreaterThanOrEqual(rect.minY, 0)
                XCTAssertLessThanOrEqual(rect.maxY, 2320)
                XCTAssertEqual(rect.width / rect.height, size.width / size.height, accuracy: 0.1)
            }
        }
        XCTAssertEqual(count, 114)
    }
}
