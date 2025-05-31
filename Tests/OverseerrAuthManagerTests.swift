#if canImport(Combine)
import XCTest
@testable import CantinarrModels

@MainActor
final class OverseerrAuthManagerTests: XCTestCase {
    final class MockService: OverseerrServiceType {
        var authResult: Bool
        var authCallCount = 0
        init(authResult: Bool) { self.authResult = authResult }
        func isAuthenticated() async -> Bool {
            authCallCount += 1
            return authResult
        }
        func fetchTrending(providerIds: [Int], page: Int) async throws -> DiscoverResponse<TrendingItem> { fatalError("not used") }
        func movieDetail(id: Int) async throws -> MovieDetail { fatalError("not used") }
        func tvDetail(id: Int) async throws -> TVDetail { fatalError("not used") }
        func request(mediaId id: Int, isMovie: Bool) async throws { fatalError("not used") }
        func reportIssue(mediaId id: Int, type: String, message: String) async throws { fatalError("not used") }
    }

    override func tearDown() {
        OverseerrAuthManager.shared.subject.send(.unknown)
    }

    func testProbeSessionAuthenticated() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.configure(service: service)
        await manager.probeSession()
        XCTAssertEqual(manager.value, .authenticated(expiry: nil))
        XCTAssertEqual(service.authCallCount, 1)
    }

    func testProbeSessionUnauthenticated() async {
        let service = MockService(authResult: false)
        let manager = OverseerrAuthManager.shared
        await manager.configure(service: service)
        await manager.probeSession()
        XCTAssertEqual(manager.value, .unauthenticated)
        XCTAssertEqual(service.authCallCount, 1)
    }

    func testEnsureAuthenticatedIsThrottled() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.configure(service: service)
        await manager.ensureAuthenticated()
        XCTAssertEqual(service.authCallCount, 1)
        await manager.ensureAuthenticated()
        XCTAssertEqual(service.authCallCount, 1)
    }

    func testRecoverFromAuthFailureTransitionsState() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.configure(service: service)
        manager.subject.send(.unauthenticated)
        await manager.recoverFromAuthFailure()
        XCTAssertEqual(manager.value, .authenticated(expiry: nil))
    }
}
#endif
