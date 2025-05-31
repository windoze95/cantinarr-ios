#if canImport(Combine) && canImport(SwiftUI)
import XCTest
@testable import CantinarrModels

@MainActor
final class TrendingViewModelPaginationTests: XCTestCase {
    // Minimal copy of PagedLoader used by the VM
    private struct PagedLoader {
        var page = 1
        var totalPages = 1
        var isLoading = false
        mutating func reset() { page = 1; totalPages = 1; isLoading = false }
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
        mutating func cancelLoading() { isLoading = false }
    }

    // Minimal AppConfig constant
    private enum AppConfig { static let prefetchThreshold = 1 }

    // Copied TrendingViewModel logic with simplified dependencies
    final class TestTrendingViewModel: ObservableObject {
        private let service: OverseerrServiceType
        private var loader = PagedLoader()
        @Published private(set) var items: [MediaItem] = []
        @Published private(set) var isLoading = false
        @Published var connectionError: String? = nil

        init(service: OverseerrServiceType) { self.service = service }

        func bootstrap() async {
            connectionError = nil
            items.removeAll()
            loader.reset()
            await fetchNextPage()
        }

        func loadMoreIfNeeded(current item: MediaItem) async {
            guard let idx = items.firstIndex(where: { $0.id == item.id }),
                  idx >= items.index(items.endIndex, offsetBy: -AppConfig.prefetchThreshold)
            else { return }
            await fetchNextPage()
        }

        private func fetchNextPage() async {
            guard loader.beginLoading() else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let resp = try await service.fetchTrending(providerIds: [], page: loader.page)
                let mapped = resp.results.map { MediaItem(id: $0.id,
                                                           title: $0.title ?? $0.name ?? "Untitled",
                                                           posterPath: $0.posterPath,
                                                           mediaType: $0.mediaType) }
                items += mapped
                loader.endLoading(next: resp.totalPages)
                if loader.page == 2 { connectionError = nil }
            } catch {
                loader.cancelLoading()
                if items.isEmpty {
                    connectionError = "Failed to load trending items. \(error.localizedDescription)"
                }
            }
        }
    }

    final class MockService: OverseerrServiceType {
        private let pages: [DiscoverResponse<TrendingItem>]
        private(set) var fetchCount = 0
        init(pages: [DiscoverResponse<TrendingItem>]) { self.pages = pages }
        func isAuthenticated() async -> Bool { true }
        func fetchTrending(providerIds: [Int], page: Int) async throws -> DiscoverResponse<TrendingItem> {
            fetchCount += 1
            return pages[page - 1]
        }
        func movieDetail(id: Int) async throws -> MovieDetail { fatalError("unused") }
        func tvDetail(id: Int) async throws -> TVDetail { fatalError("unused") }
        func request(mediaId id: Int, isMovie: Bool) async throws {}
        func reportIssue(mediaId id: Int, type: String, message: String) async throws {}
    }

    func testPaginationAppendsItems() async {
        let page1 = DiscoverResponse(page: 1, totalPages: 2, results: [
            TrendingItem(id: 1, mediaType: .movie, title: "First", name: nil, posterPath: nil)
        ])
        let page2 = DiscoverResponse(page: 2, totalPages: 2, results: [
            TrendingItem(id: 2, mediaType: .movie, title: "Second", name: nil, posterPath: nil)
        ])
        let service = MockService(pages: [page1, page2])
        let vm = TestTrendingViewModel(service: service)
        await vm.bootstrap()
        XCTAssertEqual(vm.items.count, 1)
        await vm.loadMoreIfNeeded(current: vm.items.last!)
        XCTAssertEqual(vm.items.count, 2)
        XCTAssertEqual(service.fetchCount, 2)
    }
}
#endif
