// File: RadarrSettings.swift
// Purpose: Defines RadarrSettings component for Cantinarr

import Foundation

/// Configuration for a Radarr server instance.
struct RadarrSettings: Codable {
    var host: String // e.g., "radarr.example.com" or "192.168.1.100"
    var port: String? // e.g., "7878"
    var apiKey: String // API key generated in Radarr
    var useSSL: Bool = false
    var urlBase: String? // Optional URL base, e.g., "/radarr"
    var isPrimary: Bool = false

    static func keychainKey(host: String, port: String?) -> String {
        "radarrApiKey-\(host)-\(port ?? "default")"
    }

    enum CodingKeys: String, CodingKey {
        case host
        case port
        case apiKey
        case useSSL
        case urlBase
        case isPrimary
    }

    init(host: String,
         port: String? = nil,
         apiKey: String,
         useSSL: Bool = false,
         urlBase: String? = nil,
         isPrimary: Bool = false)
    {
        self.host = host
        self.port = port
        self.apiKey = apiKey
        self.useSSL = useSSL
        self.urlBase = urlBase
        self.isPrimary = isPrimary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decodeIfPresent(String.self, forKey: .port)
        useSSL = try container.decodeIfPresent(Bool.self, forKey: .useSSL) ?? false
        urlBase = try container.decodeIfPresent(String.self, forKey: .urlBase)
        isPrimary = try container.decodeIfPresent(Bool.self, forKey: .isPrimary) ?? false

        // API key may come from JSON for backward compatibility
        if let key = try container.decodeIfPresent(String.self, forKey: .apiKey) {
            apiKey = key
            if let data = key.data(using: .utf8) {
                KeychainHelper.save(key: RadarrSettings.keychainKey(host: host, port: port), data: data)
            }
        } else if let data = KeychainHelper.load(key: RadarrSettings.keychainKey(host: host, port: port)),
                  let key = String(data: data, encoding: .utf8) {
            apiKey = key
        } else {
            apiKey = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(host, forKey: .host)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encode(useSSL, forKey: .useSSL)
        try container.encodeIfPresent(urlBase, forKey: .urlBase)
        try container.encode(isPrimary, forKey: .isPrimary)
        // Omit apiKey from encoded JSON – it's stored in Keychain
    }
}
