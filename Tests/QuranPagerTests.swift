import XCTest
import SwiftUI
import UIKit
@testable import CoranNative

@MainActor
final class QuranPagerTests: XCTestCase {
    func testUIKitCanRequestCandidateBeforeWindowAdvances() throws {
        let pager = QuranPager(source: .medina, page: .constant(1), onTap: {})
        let coordinator = pager.makeCoordinator()
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        coordinator.controller = controller
        coordinator.present(page: 1, source: .medina)
        let first = try XCTUnwrap(controller.viewControllers?.first)
        let second = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerBefore: first) as? PageController)
        // The transition delegate has not yet committed page 2.
        XCTAssertEqual(coordinator.current, 1)
        let third = try XCTUnwrap(coordinator.pageViewController(controller, viewControllerBefore: second) as? PageController)
        XCTAssertEqual(second.page, 2)
        XCTAssertEqual(third.page, 3)
        XCTAssertTrue(coordinator.pageViewController(controller, viewControllerBefore: second) === third)
        XCTAssertNil(coordinator.pageViewController(controller, viewControllerAfter: first))
        XCTAssertNil(coordinator.pageViewController(controller, viewControllerBefore: PageController(page: 604, onTap: {})))
    }
}
