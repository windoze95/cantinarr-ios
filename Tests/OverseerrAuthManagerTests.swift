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


    func testProbeSessionAuthenticated() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.setState(.unknown)
        await manager.configure(service: service)
        await Task.yield()
        await manager.probeSession()
        let current = await manager.currentValue()
        XCTAssertEqual(current, .authenticated(expiry: nil))
        XCTAssertEqual(service.authCallCount, 2)
    }

    func testProbeSessionUnauthenticated() async {
        let service = MockService(authResult: false)
        let manager = OverseerrAuthManager.shared
        await manager.setState(.unknown)
        await manager.configure(service: service)
        await Task.yield()
        await manager.probeSession()
        let current = await manager.currentValue()
        XCTAssertEqual(current, .unauthenticated)
        XCTAssertEqual(service.authCallCount, 2)
    }

    func testEnsureAuthenticatedIsThrottled() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.setState(.unknown)
        await manager.configure(service: service, autoProbe: false)
        service.authCallCount = 0
        await manager.ensureAuthenticated()
        XCTAssertEqual(service.authCallCount, 1)
        await manager.ensureAuthenticated()
        XCTAssertEqual(service.authCallCount, 1)
    }

    func testRecoverFromAuthFailureTransitionsState() async {
        let service = MockService(authResult: true)
        let manager = OverseerrAuthManager.shared
        await manager.setState(.unknown)
        await manager.configure(service: service)
        await Task.yield()
        await manager.setState(.unauthenticated)
        await manager.recoverFromAuthFailure()
        let current = await manager.currentValue()
        XCTAssertEqual(current, .authenticated(expiry: nil))
    }
}
#endif
