// File: OverseerrAPIService.swift
// Purpose: Defines OverseerrAPIService component for Cantinarr

import Combine
import Foundation
import WebKit

/// Shared cookie store so that WKWebView and URLSession share authentication cookies.
private let sharedDataStore = WKWebsiteDataStore.default()

/// Errors specific to Overseerr API interactions.
enum OverseerrError: Error, LocalizedError {
    case notAuthenticated
    case apiError(message: String, statusCode: Int)
    case invalidResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication required."
        case let .apiError(message, _):
            return message
        case .invalidResponse:
            return "Invalid response from server."
        case let .network(error):
            return error.localizedDescription
        }
    }
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

    let jsonDecoder: JSONDecoder = {
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
        do {
            let (data, response) = try await session.data(for: req, delegate: nil)

            guard let http = response as? HTTPURLResponse else {
                throw OverseerrError.invalidResponse
            }

            if http.statusCode == 401 || http.statusCode == 403 {
                await OverseerrAuthManager.shared.recoverFromAuthFailure()
                throw OverseerrError.notAuthenticated
            }

            guard (200 ... 299).contains(http.statusCode) else {
                throw OverseerrError.apiError(
                    message: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                    statusCode: http.statusCode
                )
            }

            return (data, http)
        } catch let error as OverseerrError {
            throw error
        } catch {
            throw OverseerrError.network(error)
        }
    }
}

// Make OverseerrAPIService satisfy OverseerrUsersService
extension OverseerrAPIService: OverseerrUsersService {}

extension OverseerrAPIService: OverseerrServiceType {}
