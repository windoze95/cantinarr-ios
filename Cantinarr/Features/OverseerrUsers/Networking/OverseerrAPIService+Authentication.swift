// File: OverseerrAPIService+Authentication.swift
// Purpose: Authentication related helpers for OverseerrAPIService

import Foundation

extension OverseerrAPIService {
    struct User: Codable { // Matches /auth/me response
        let id: Int
        let username: String?
        let email: String?
        let permissions: Int?
        let requestCount: Int?
        let avatar: String?
    }

    /// Checks if there is a valid login session (`/auth/me`).
    func isAuthenticated() async -> Bool {
        let url = baseURL.appendingPathComponent("auth/me")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        do {
            let (_, http) = try await data(for: req)
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    func fetchCurrentUser() async throws -> User {
        let req = URLRequest(url: baseURL.appendingPathComponent("auth/me"))
        let (data, resp) = try await data(for: req)
        guard resp.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(User.self, from: data)
    }

    func plexSSORedirectURL() async throws -> URL {
        let endpoint = baseURL.appendingPathComponent("auth/plex")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data()

        let (data, resp) = try await data(for: request)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        struct Redirect: Decodable { let url: String }
        let redirect = try JSONDecoder().decode(Redirect.self, from: data)
        guard let plexURL = URL(string: redirect.url) else { throw URLError(.badURL) }
        return plexURL
    }

    /// Exchange a Plex auth token for an Overseerr session.
    func loginWithPlexToken(_ plexToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/plex")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["authToken": plexToken]
        req.httpBody = try JSONEncoder().encode(body)

        let (_, resp) = try await data(for: req)
        guard resp.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }
    }
}
