import AuthenticationServices
import Foundation

@MainActor
final class PlexSSOHandler {
    private let service: OverseerrUsersService
    private let settingsKey: String
    private let authContext: OverseerrAuthContextProvider
    private var tokenKey: String { "plexAuthToken-\(settingsKey)" }

    private var webSession: ASWebAuthenticationSession?

    private let clientID: String = {
        let key = "PlexClientID"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let uuid = UUID().uuidString
        UserDefaults.standard.set(uuid, forKey: key)
        return uuid
    }()

    private let productName = "Cantinarr"

    init(service: OverseerrUsersService, settingsKey: String, authContext: OverseerrAuthContextProvider) {
        self.service = service
        self.settingsKey = settingsKey
        self.authContext = authContext
    }

    func startLogin() async throws -> String {
        let pin = try await fetchPlexPIN()
        let plexURL = buildPlexOAuthURL(code: pin.code)
        let web = ASWebAuthenticationSession(url: plexURL, callbackURLScheme: nil) { _, error in
            if let err = error as? ASWebAuthenticationSessionError, err.code != .canceledLogin {
                debugLog("ASWebAuthenticationSession failed: \(err.localizedDescription)")
            }
        }
        web.presentationContextProvider = authContext
        web.prefersEphemeralWebBrowserSession = true
        web.start()
        webSession = web

        let authToken = try await pollForPlexToken(pinID: pin.id, code: pin.code)
        try await service.loginWithPlexToken(authToken)
        saveTokenToKeychain(authToken)
        webSession = nil
        return authToken
    }

    func saveTokenToKeychain(_ token: String) {
        if let data = token.data(using: .utf8) {
            KeychainHelper.save(key: tokenKey, data: data)
        }
    }

    func loadTokenFromKeychain() -> String? {
        guard let data = KeychainHelper.load(key: tokenKey),
              let token = String(data: data, encoding: .utf8)
        else { return nil }
        return token
    }

    func deleteTokenFromKeychain() {
        KeychainHelper.delete(key: tokenKey)
    }

    private struct PlexPIN: Decodable { let id: Int; let code: String; let authToken: String? }

    private func fetchPlexPIN() async throws -> PlexPIN {
        var req = URLRequest(url: URL(string: "https://plex.tv/api/v2/pins?strong=true")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(productName, forHTTPHeaderField: "X-Plex-Product")
        req.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 201 else {
            throw URLError(
                .badServerResponse,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to fetch Plex PIN (status: \((resp as? HTTPURLResponse)?.statusCode ?? 0))",
                ]
            )
        }
        return try JSONDecoder().decode(PlexPIN.self, from: data)
    }

    private func pollForPlexToken(pinID: Int, code _: String) async throws -> String {
        for _ in 0 ..< 120 {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            try Task.checkCancellation()
            let url = URL(string: "https://plex.tv/api/v2/pins/\(pinID)")!
            var req = URLRequest(url: url)
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue(clientID, forHTTPHeaderField: "X-Plex-Client-Identifier")
            req.setValue(productName, forHTTPHeaderField: "X-Plex-Product")

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { continue }
            if http.statusCode == 404 {
                throw URLError(
                    .cancelled,
                    userInfo: [NSLocalizedDescriptionKey: "Plex PIN expired or invalid."]
                )
            }
            guard http.statusCode == 200 else { continue }

            guard let status = try? JSONDecoder().decode(PlexPIN.self, from: data) else { continue }
            if let token = status.authToken, !token.isEmpty { return token }
        }
        throw URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "Plex login timed out."])
    }

    private func buildPlexOAuthURL(code: String) -> URL {
        var base = URLComponents()
        base.scheme = "https"
        base.host = "app.plex.tv"
        base.path = "/auth"

        var fragComps = URLComponents()
        fragComps.queryItems = [
            .init(name: "clientID", value: clientID),
            .init(name: "code", value: code),
            .init(name: "context[device][product]", value: productName),
        ]
        base.fragment = "?" + (fragComps.percentEncodedQuery ?? "")
        return base.url!
    }
}
