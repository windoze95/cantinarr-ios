import Foundation

@MainActor
protocol OverseerrServiceType {
    func isAuthenticated() async -> Bool
    func fetchTrending(providerIds: [Int], page: Int) async throws -> OverseerrAPIService.DiscoverResponse<OverseerrAPIService.TrendingItem>
    func movieDetail(id: Int) async throws -> OverseerrAPIService.MovieDetail
    func tvDetail(id: Int) async throws -> OverseerrAPIService.TVDetail
    func request(mediaId id: Int, isMovie: Bool) async throws
    func reportIssue(mediaId id: Int, type: String, message: String) async throws
}
