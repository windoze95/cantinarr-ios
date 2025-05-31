import XCTest
@testable import CantinarrModels

#if canImport(Combine) && canImport(SwiftUI)
import Combine

private actor MockOverseerrService: OverseerrServiceType {
    private var isAuthenticatedResult: Bool = false
    private(set) var isAuthenticatedCallCount = 0

    func setIsAuthenticatedResult(_ value: Bool) {
        isAuthenticatedResult = value
    }

    func getIsAuthenticatedCallCount() -> Int { isAuthenticatedCallCount }

    func isAuthenticated() async -> Bool {
        isAuthenticatedCallCount += 1
        return isAuthenticatedResult
    }

    func fetchTrending(providerIds: [Int], page: Int) async throws -> DiscoverResponse<TrendingItem> {
        fatalError("Not implemented")
    }

    func movieDetail(id: Int) async throws -> MovieDetail {
        fatalError("Not implemented")
    }

    func tvDetail(id: Int) async throws -> TVDetail {
        fatalError("Not implemented")
    }

    func request(mediaId id: Int, isMovie: Bool) async throws {
        fatalError("Not implemented")
    }

    func reportIssue(mediaId id: Int, type: String, message: String) async throws {
        fatalError("Not implemented")
    }
}

final class OverseerrAuthManagerTests: XCTestCase {
    func testEnsureAuthenticatedPublishesAuthenticatedAndThrottles() async {
        let service = await MockOverseerrService()
        await service.setIsAuthenticatedResult(true)

        await OverseerrAuthManager.shared.configure(service: service)
        // Wait for initial probe to finish
        try? await Task.sleep(nanoseconds: 50_000_000)
        let initialCount = await service.getIsAuthenticatedCallCount()

        await OverseerrAuthManager.shared.ensureAuthenticated()
        XCTAssertEqual(OverseerrAuthManager.shared.value, .authenticated(expiry: nil))
        let firstCount = await service.getIsAuthenticatedCallCount()
        XCTAssertEqual(firstCount, initialCount + 1)

        await OverseerrAuthManager.shared.ensureAuthenticated()
        let secondCount = await service.getIsAuthenticatedCallCount()
        XCTAssertEqual(secondCount, firstCount)
    }

    func testRecoverFromAuthFailureResetsAndProbes() async {
        let service = await MockOverseerrService()
        await service.setIsAuthenticatedResult(true)

        await OverseerrAuthManager.shared.configure(service: service)
        await OverseerrAuthManager.shared.ensureAuthenticated()
        let initialCount = await service.getIsAuthenticatedCallCount()

        let exp = expectation(description: "states")
        exp.expectedFulfillmentCount = 2
        var states: [OverseerrAuthState] = []
        let cancellable = OverseerrAuthManager.shared.publisher.dropFirst().sink { state in
            states.append(state)
            if states.count == 2 { exp.fulfill() }
        }

        Task { await OverseerrAuthManager.shared.recoverFromAuthFailure() }
        await fulfillment(of: [exp], timeout: 1)
        cancellable.cancel()

        XCTAssertEqual(states.first, .unknown)
        XCTAssertEqual(states.last, .authenticated(expiry: nil))
        let finalCount = await service.getIsAuthenticatedCallCount()
        XCTAssertEqual(finalCount, initialCount + 1)
    }
}
#endif
