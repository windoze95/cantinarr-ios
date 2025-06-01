import Foundation

protocol OverseerrServiceType {
    func isAuthenticated() async -> Bool
    func fetchTrending(providerIds: [Int], page: Int) async throws -> DiscoverResponse<TrendingItem>
    func movieDetail(id: Int) async throws -> MovieDetail
    func tvDetail(id: Int) async throws -> TVDetail
    func request(mediaId id: Int, isMovie: Bool) async throws
    func reportIssue(mediaId id: Int, type: String, message: String) async throws
}
