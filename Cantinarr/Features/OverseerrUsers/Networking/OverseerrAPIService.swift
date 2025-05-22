// File: OverseerrAPIService.swift
// Purpose: Defines OverseerrAPIService component for Cantinarr

import Combine
import Foundation
import WebKit

/// Shared cookie store so that WKWebView and URLSession share authentication cookies.
private let sharedDataStore = WKWebsiteDataStore.default()

enum AuthError: Error {
    case notAuthenticated
}

struct User: Codable { // This struct should match the /auth/me response
    let id: Int
    let username: String?
    let email: String? // Add if present in /auth/me
    let permissions: Int? // Bitmask or specific permission flags
    let requestCount: Int? // Total requests made by user
    let avatar: String? // Add if present
    // Add other fields like 'movieQuotaLimit', 'movieQuotaDays', 'tvQuotaLimit', 'tvQuotaDays'
    // and 'movieRequestsRemaining', 'tvRequestsRemaining' if the API provides them directly.
}

@MainActor
class OverseerrAPIService {
    // MARK: – Configuration

    let host: String
    let port: String?
    let useSSL: Bool
    /// e.g. https://my‑server[:port]/api/v1
    let baseURL: URL
    /// URLSession that shares cookies with WKWebView
    private let session: URLSession

    private let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: - Convenience initializer

    convenience init(settings: OverseerrSettings) {
        self.init(host: settings.host,
                  port: settings.port,
                  useSSL: settings.useSSL)
    }

    init(host: String, port: String?, useSSL: Bool) {
        self.host = host
        self.port = port
        self.useSSL = useSSL

        let scheme = useSSL ? "https" : "http"

        // pick scheme based on useSSL
        var comps = URLComponents()
        comps.scheme = scheme
        comps.host = host
        if let p = port, !p.isEmpty {
            comps.port = Int(p)
        }
        comps.path = "/api/v1"
        guard let url = comps.url else {
            fatalError("Invalid Overseerr base URL")
        }
        baseURL = url

        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: cfg)
    }

    // MARK: – Unified request helper

    @discardableResult
    func data(for req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // hit the network through the dedicated session
        let (data, response) = try await session.data(for: req, delegate: nil)

        // validate HTTP
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // translate auth errors so callers & AuthManager can react
        if http.statusCode == 401 || http.statusCode == 403 {
            await AuthManager.shared.recoverFromAuthFailure()
            throw AuthError.notAuthenticated
        }

        return (data, http)
    }

}

// Make OverseerrAPIService satisfy OverseerrUsersService
extension OverseerrAPIService: OverseerrUsersService {}

extension OverseerrAPIService: OverseerrServiceType {}
