// File: RadarrAPIService.swift
// Purpose: Defines RadarrAPIService component for Cantinarr

import Combine // Import Combine for ObservableObject
import Foundation

@MainActor
class RadarrAPIService: ObservableObject { // ADDED ObservableObject conformance
    private let settings: RadarrSettings
    private let baseURL: URL
    private let session: URLSession
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        // Radarr v3+ uses ISO8601-like dates but sometimes without milliseconds.
        // A custom strategy might be needed if strict ISO8601 parsing fails for some date fields.
        // For now, .iso8601 is a good starting point.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = formatter.date(from: dateString) {
                return date
            }
            if let date = fractionalSecondsFormatter.date(from: dateString) {
                return date
            }
            // Handle Radarr's "0001-01-01T00:00:00Z" or similar invalid/min dates gracefully
            if dateString == "0001-01-01T00:00:00Z" || dateString.hasPrefix("0001-01-01") { // Check for min date
                return Date.distantPast // Or throw a specific error
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date string \(dateString)"
            )
        }
        return decoder
    }()

    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    // This computed property can still exist for use *after* initialization
    private var apiKey: String {
        // Attempt to load from Keychain first
        let keychainKey = "radarrApiKey-\(settings.host)-\(settings.port ?? "default")"
        if let data = KeychainHelper.load(key: keychainKey),
           let key = String(data: data, encoding: .utf8)
        {
            return key
        }
        // Fallback to settings, and save it for next time if not in Keychain
        // This part of the computed property is fine, as 'settings' will be initialized
        // when this is called *after* init completes.
        if let apiKeyData = settings.apiKey.data(using: .utf8) {
            KeychainHelper.save(key: keychainKey, data: apiKeyData)
        }
        return settings.apiKey
    }

    init(settings: RadarrSettings) {
        self.settings = settings // Initialize 'settings' first

        // Now calculate the API key string needed for session configuration
        // This local calculation is safe because 'self.settings' is now initialized.
        let currentApiKey: String
        let keychainKey = "radarrApiKey-\(settings.host)-\(settings.port ?? "default")"
        if let data = KeychainHelper.load(key: keychainKey),
           let key = String(data: data, encoding: .utf8)
        {
            currentApiKey = key
        } else {
            if let apiKeyData = settings.apiKey.data(using: .utf8) {
                KeychainHelper.save(key: keychainKey, data: apiKeyData)
            }
            currentApiKey = settings.apiKey
        }

        // Initialize 'baseURL'
        var components = URLComponents()
        components.scheme = settings.useSSL ? "https" : "http"
        components.host = settings.host
        if let portString = settings.port, let portInt = Int(portString) {
            components.port = portInt
        }
        if let urlBase = settings.urlBase?.trimmingCharacters(in: CharacterSet(charactersIn: "/")), !urlBase.isEmpty {
            components.path = "/" + urlBase
        }
        components.path += "/api/v3"

        guard let url = components.url else {
            fatalError("Invalid Radarr base URL constructed: \(components.string ?? "N/A")")
        }
        baseURL = url // Initialize 'baseURL'

        // Configure and initialize 'session'
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["X-Api-Key": currentApiKey] // Use the locally computed apiKey
        session = URLSession(configuration: config) // Initialize 'session' last
    }

    private func performRequest<T: Decodable>(endpoint: String, method: String = "GET",
                                              body: Data? = nil) async throws -> T
    {
        // Build the request for the given endpoint
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        // The computed `self.apiKey` is now accessible here because init is complete
        // However, the session's headers already have the API key.
        // If you needed to add it per-request for some reason (not typical if in session config):
        // request.setValue(self.apiKey, forHTTPHeaderField: "X-Api-Key")
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Hit the network
        let (data, response) = try await session.data(for: request)

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }

        // Translate non‑2xx responses into descriptive errors
        if !(200 ... 299).contains(httpResponse.statusCode) {
            if let errorDetailArray = try? jsonDecoder.decode([RadarrErrorDetail].self, from: data),
               let firstError = errorDetailArray.first
            {
                throw RadarrError.apiError(
                    message: firstError.resolvedErrorMessage ?? "Radarr API Error \(httpResponse.statusCode)",
                    statusCode: httpResponse.statusCode
                )
            } else if let singleErrorDetail = try? jsonDecoder.decode(RadarrErrorDetail.self, from: data) {
                throw RadarrError.apiError(
                    message: singleErrorDetail.resolvedErrorMessage ?? "Radarr API Error \(httpResponse.statusCode)",
                    statusCode: httpResponse.statusCode
                )
            } else if let errorString = String(data: data, encoding: .utf8), !errorString.isEmpty {
                throw RadarrError.apiError(
                    message: "Radarr API Error \(httpResponse.statusCode): \(errorString)",
                    statusCode: httpResponse.statusCode
                )
            }
            throw RadarrError.apiError(
                message: "Radarr API Error \(httpResponse.statusCode)",
                statusCode: httpResponse.statusCode
            )
        }

        do {
            // Attempt to decode the payload using the shared decoder
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            // Log the raw payload to aid debugging
            print("🔴 Radarr decoding error for endpoint \(endpoint): \(error)")
            if let rawDataString = String(data: data, encoding: .utf8) {
                print("🔴 Raw data: \(rawDataString)")
            } else {
                print("🔴 Raw data: Could not decode as UTF-8")
            }
            throw error
        }
    }

    private struct RadarrErrorDetail: Codable {
        let propertyName: String?
        let errorMessage: String? // Radarr v4 uses "errorMessage", v3 might use "message"
        let message: String? // Adding this for compatibility if Radarr's error object changes
        let severity: String?

        // Consolidate error message
        var resolvedErrorMessage: String? {
            errorMessage ?? message
        }
    }

    enum RadarrError: Error, LocalizedError {
        case apiError(message: String, statusCode: Int)
        case invalidParameters

        var errorDescription: String? {
            switch self {
            case let .apiError(message, _): return message
            case .invalidParameters: return "Invalid parameters provided for Radarr API request."
            }
        }
    }

    // MARK: - API Endpoints

    func getMovies() async throws -> [RadarrMovie] {
        try await performRequest(endpoint: "movie")
    }

    func getMovie(id: Int) async throws -> RadarrMovie {
        try await performRequest(endpoint: "movie/\(id)")
    }

    func getMovieHistory(movieId: Int) async throws -> [RadarrMovieHistoryRecord] {
        try await performRequest(endpoint: "history/movie?movieId=\(movieId)")
    }

    func getQualityProfiles() async throws -> [RadarrQualityProfile] {
        try await performRequest(endpoint: "qualityprofile")
    }

    func getRootFolders() async throws -> [RadarrRootFolder] {
        try await performRequest(endpoint: "rootfolder")
    }

    func getSystemStatus() async throws -> RadarrSystemStatus {
        try await performRequest(endpoint: "system/status")
    }

    func addMovie(
        _ movie: RadarrMovie,
        addOptions: RadarrAddOptions,
        rootFolderPath: String,
        qualityProfileId: Int
    ) async throws -> RadarrMovie {
        struct AddMoviePayload: Codable {
            let title: String
            let year: Int
            let qualityProfileId: Int
            let titleSlug: String?
            let tmdbId: Int
            let images: [RadarrImage]
            let rootFolderPath: String
            let monitored: Bool
            let addOptions: RadarrAddOptions
            let path: String? // Optional: Radarr can determine this.
            let minimumAvailability: String // Should match Radarr's expected values e.g. "announced"
            let overview: String?
            let runtime: Int
            // You might need other fields like 'genres' if Radarr requires them on add.
        }

        guard let tmdbId = movie.tmdbId else { throw RadarrError.invalidParameters }

        let payload = AddMoviePayload(
            title: movie.title,
            year: movie.year,
            qualityProfileId: qualityProfileId,
            titleSlug: movie.titleSlug ?? RadarrAPIService.generateSlug(for: movie.title, year: movie.year),
            tmdbId: tmdbId,
            images: movie.images,
            rootFolderPath: rootFolderPath,
            monitored: movie.monitored, // Use the movie's monitored state or default to true
            addOptions: addOptions,
            path: nil, // Let Radarr determine the path on add
            minimumAvailability: movie.minimumAvailability, // Pass existing or a default
            overview: movie.overview,
            runtime: movie.runtime
        )

        let body = try jsonEncoder.encode(payload)
        return try await performRequest(endpoint: "movie", method: "POST", body: body)
    }

    private struct MovieSearchCommandPayload: Encodable {
        let name: String
        let movieIds: [Int]
    }

    func searchForMovie(_ movieId: Int) async throws -> RadarrCommandResponse {
        let commandPayload = MovieSearchCommandPayload(name: "MoviesSearch", movieIds: [movieId])
        let body = try jsonEncoder.encode(commandPayload) // Now encodes a concrete Encodable type
        return try await performRequest(endpoint: "command", method: "POST", body: body)
    }

    func updateMovie(_ movie: RadarrMovie, moveFiles: Bool = false) async throws -> RadarrMovie {
        // Radarr's PUT /movie/{id} expects the full movie object.
        // Ensure the movie object being sent is complete and correct.
        let endpoint = "movie/\(movie.id)?moveFiles=\(moveFiles)"
        let body = try jsonEncoder.encode(movie)
        return try await performRequest(endpoint: endpoint, method: "PUT", body: body)
    }

    func deleteMovie(_ movieId: Int, deleteFiles: Bool = false, addImportExclusion: Bool = false) async throws {
        let endpoint = "movie/\(movieId)?deleteFiles=\(deleteFiles)&addImportListExclusion=\(addImportExclusion)"
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200 ... 299).contains(httpResponse.statusCode) else {
            throw RadarrError.apiError(
                message: "Failed to delete movie. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0)",
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
    }

    static func generateSlug(for title: String, year: Int) -> String {
        let alphanumericTitle = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet.whitespaces).inverted)
            .joined()
            .replacingOccurrences(of: " ", with: "-")
        return "\(alphanumericTitle)-\(year)".replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
    }

    // Renamed to avoid conflict if you add a model named MovieHistoryRecord
    struct RadarrMovieHistoryRecord: Codable, Identifiable { // Corrected struct name
        let id: Int
        let movieId: Int
        let sourceTitle: String?
        let quality: RadarrHistoryQuality?
        let qualityCutoffNotMet: Bool?
        let date: Date?
        let eventType: String? // e.g. "grabbed", "downloadFolderImported", "downloadFailed"
        let data: RadarrHistoryData?
    }

    struct RadarrHistoryQuality: Codable {
        let quality: RadarrQualityDetail?
        let revision: RadarrRevision?
    }

    struct RadarrQualityDetail: Codable {
        let id: Int?
        let name: String?
        let source: String?
        let resolution: Int?
    }

    struct RadarrRevision: Codable {
        let version: Int?
        let real: Int?
        let isRepack: Bool?
    }

    struct RadarrHistoryData: Codable {
        let nzbInfoUrl: String? // Note: Radarr's casing might vary
        let releaseGroup: String?
        let age: String? // Radarr often returns age as a string like "1d" or "1h"
        // ... other fields that might appear in the 'data' dictionary
        let message: String?
        let reason: String? // For failed events
        let downloadClient: String?
        let downloadClientName: String?

        // Custom coding keys if JSON keys are different (e.g., "NzbInfoUrl" vs "nzbInfoUrl")
        enum CodingKeys: String, CodingKey {
            case nzbInfoUrl
            case releaseGroup
            case age
            case message
            case reason
            case downloadClient
            case downloadClientName
        }
    }
}
