#if canImport(Combine) && canImport(SwiftUI)
import XCTest
import Combine
@testable import CantinarrModels

@MainActor
final class SearchControllerTests: XCTestCase {
    final class MockService: OverseerrUsersService {
        var searchCallCount = 0
        var searchResponse: DiscoverResponse<SearchItem>
        var keywordResults: [Keyword] = []
        var movieRecResponse = DiscoverResponse(page: 1, totalPages: 1, results: [Movie(id: 10, title: "Rec", posterPath: nil, genreIds: nil)])
        var tvRecResponse = DiscoverResponse(page: 1, totalPages: 1, results: [TVShow(id: 20, name: "Rec", posterPath: nil, genreIds: nil)])
        init(searchResponse: DiscoverResponse<SearchItem>) {
            self.searchResponse = searchResponse
        }
        func isAuthenticated() async -> Bool { true }
        func loginWithPlexToken(_ token: String) async throws {}
        func fetchWatchProviders(isMovie: Bool) async throws -> [WatchProvider] { [] }
        func fetchMovies(providerIds: [Int], genreIds: [Int], keywordIds: [Int], page: Int) async throws -> DiscoverResponse<Movie> {
            DiscoverResponse(page: 1, totalPages: 1, results: [])
        }
        func fetchTV(providerIds: [Int], genreIds: [Int], keywordIds: [Int], page: Int) async throws -> DiscoverResponse<TVShow> {
            DiscoverResponse(page: 1, totalPages: 1, results: [])
        }
        func keywordSearch(query: String) async throws -> [Keyword] { keywordResults }
        func movieRecommendations(for id: Int, page: Int) async throws -> DiscoverResponse<Movie> { movieRecResponse }
        func tvRecommendations(for id: Int, page: Int) async throws -> DiscoverResponse<TVShow> { tvRecResponse }
        func search(query: String, page: Int) async throws -> DiscoverResponse<SearchItem> {
            searchCallCount += 1
            return searchResponse
        }
    }

    func testSearchQueryLoadsResults() async throws {
        let item = SearchItem(id: 1, mediaType: .movie, title: "First", name: nil, posterPath: nil)
        let service = MockService(searchResponse: DiscoverResponse(page: 1, totalPages: 1, results: [item]))
        let controller = SearchController(
            service: service,
            filters: FilterManager(),
            keywordActivatedSubject: .init(),
            recoverAuth: {},
            clearConnectionError: {},
            setConnectionError: { _ in },
            loadDiscover: { _ in }
        )
        controller.searchQuery = "A"
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(service.searchCallCount, 1)
        XCTAssertEqual(controller.results.first?.id, 1)
        XCTAssertFalse(controller.movieRecs.isEmpty)
        XCTAssertFalse(controller.tvRecs.isEmpty)
    }

    func testClearingQueryCallsDiscover() async throws {
        let item = SearchItem(id: 1, mediaType: .movie, title: "First", name: nil, posterPath: nil)
        let service = MockService(searchResponse: DiscoverResponse(page: 1, totalPages: 1, results: [item]))
        var discoverCalled = false
        let controller = SearchController(
            service: service,
            filters: FilterManager(),
            keywordActivatedSubject: .init(),
            recoverAuth: {},
            clearConnectionError: {},
            setConnectionError: { _ in },
            loadDiscover: { _ in discoverCalled = true }
        )
        controller.searchQuery = "A"
        try await Task.sleep(nanoseconds: 500_000_000)
        controller.searchQuery = ""
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(discoverCalled)
        XCTAssertTrue(controller.results.isEmpty)
    }
}
#endif
