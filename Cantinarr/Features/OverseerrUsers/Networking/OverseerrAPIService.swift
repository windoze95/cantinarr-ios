// File: OverseerrAPIService.swift
// Purpose: Defines the core OverseerrAPIService used throughout the app.

import Foundation
import WebKit

/// Shared cookie store so that WKWebView and URLSession share authentication cookies.
private let sharedDataStore = WKWebsiteDataStore.default()

enum AuthError: Error {
    case notAuthenticated
}

@MainActor
class OverseerrAPIService {
    // MARK: - Configuration
    let host: String
    let port: String?
    let useSSL: Bool
    /// e.g. https://my-server[:port]/api/v1
    let baseURL: URL
    /// URLSession that shares cookies with WKWebView
    private let session: URLSession

    // Decoder used across extensions
    fileprivate let jsonDecoder: JSONDecoder = {
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

        var comps = URLComponents()
        comps.scheme = useSSL ? "https" : "http"
        comps.host = host
        if let p = port, !p.isEmpty { comps.port = Int(p) }
        comps.path = "/api/v1"
        guard let url = comps.url else { fatalError("Invalid Overseerr base URL") }
        baseURL = url

        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = HTTPCookieStorage.shared
        cfg.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: cfg)
    }

    // MARK: - Networking helper
    @discardableResult
    func data(for req: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: req, delegate: nil)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 401 || http.statusCode == 403 {
            await AuthManager.shared.recoverFromAuthFailure()
            throw AuthError.notAuthenticated
        }
        return (data, http)
    }
}

// Conformances for dependency injection
extension OverseerrAPIService: OverseerrUsersService {}
extension OverseerrAPIService: OverseerrServiceType {}
