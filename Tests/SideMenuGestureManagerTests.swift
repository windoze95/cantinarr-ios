#if canImport(Combine) && canImport(SwiftUI)
import XCTest
@testable import CantinarrModels

final class SideMenuGestureManagerTests: XCTestCase {
    func testShouldOpenWhenDraggedPastThreshold() {
        let mgr = SideMenuGestureManager(openMenu: {}, closeMenu: {}, dragThreshold: 40)
        XCTAssertTrue(mgr.shouldOpen(for: CGSize(width: 41, height: 0)))
        XCTAssertFalse(mgr.shouldOpen(for: CGSize(width: 30, height: 0)))
    }

    func testShouldCloseWhenDraggedPastThreshold() {
        let mgr = SideMenuGestureManager(openMenu: {}, closeMenu: {}, dragThreshold: 40)
        XCTAssertTrue(mgr.shouldClose(for: CGSize(width: -41, height: 0)))
        XCTAssertFalse(mgr.shouldClose(for: CGSize(width: -30, height: 0)))
    }
}
#endif
