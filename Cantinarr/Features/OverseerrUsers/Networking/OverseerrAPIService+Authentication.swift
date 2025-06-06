import Foundation

extension OverseerrAPIService {
    // MARK: - Authentication

    /// Checks if there is a valid login session (overseerr’s cookie-based `/auth/me`).
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
        let request = URLRequest(url: baseURL.appendingPathComponent("auth/me"))
        let (data, _) = try await data(for: request)
        return try jsonDecoder.decode(User.self, from: data)
    }

    // MARK: - Plex SSO

    func plexSSORedirectURL() async throws -> URL {
        let endpoint = baseURL.appendingPathComponent("auth/plex")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = Data()

        let (data, _) = try await data(for: request)

        struct Redirect: Decodable { let url: String }
        let redirect = try JSONDecoder().decode(Redirect.self, from: data)
        guard let plexURL = URL(string: redirect.url) else { throw URLError(.badURL) }
        return plexURL
    }

    /// Exchange a Plex authToken for an Overseerr session.
    func loginWithPlexToken(_ plexToken: String) async throws {
        let url = baseURL.appendingPathComponent("auth/plex")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = ["authToken": plexToken]
        req.httpBody = try JSONEncoder().encode(body)

        _ = try await data(for: req)
    }
}
