import XCTest
@testable import CantinarrModels

@MainActor
private struct PagedLoader {
    private(set) var page = 1
    private(set) var totalPages = 1
    private(set) var isLoading = false

    mutating func reset() {
        page = 1
        totalPages = 1
        isLoading = false
    }

    mutating func beginLoading() -> Bool {
        guard !isLoading, page <= totalPages else { return false }
        isLoading = true
        return true
    }

    mutating func endLoading(next total: Int) {
        totalPages = total
        page += 1
        isLoading = false
    }

    mutating func cancelLoading() {
        isLoading = false
    }
}

final class PagedLoaderTests: XCTestCase {
    func testInitialValues() async {
        await MainActor.run {
            let loader = PagedLoader()
            XCTAssertEqual(loader.page, 1)
            XCTAssertEqual(loader.totalPages, 1)
            XCTAssertFalse(loader.isLoading)
        }
    }

    func testBeginAndEndLoadingFlow() async {
        await MainActor.run {
            var loader = PagedLoader()
            XCTAssertTrue(loader.beginLoading())
            XCTAssertTrue(loader.isLoading)

            loader.endLoading(next: 5)
            XCTAssertEqual(loader.page, 2)
            XCTAssertEqual(loader.totalPages, 5)
            XCTAssertFalse(loader.isLoading)
        }
    }

    func testCancelLoadingDoesNotAffectPage() async {
        await MainActor.run {
            var loader = PagedLoader()
            XCTAssertTrue(loader.beginLoading())
            loader.cancelLoading()
            XCTAssertFalse(loader.isLoading)
            XCTAssertEqual(loader.page, 1)
        }
    }
}
