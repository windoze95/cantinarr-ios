// File: MediaType.swift
// Purpose: Defines MediaType component for Cantinarr

import Foundation

/// A subset of TMDB media types recognised by the app.
enum MediaType: String, Codable, CaseIterable, Identifiable {
    case movie
    case tv
    case person
    case collection
    case unknown

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try? container.decode(String.self)

        switch raw {
        case Self.movie.rawValue: self = .movie
        case Self.tv.rawValue: self = .tv
        case Self.person.rawValue: self = .person
        case Self.collection.rawValue: self = .collection
        default: self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue == "unknown" ? "" : rawValue)
    }

    // UI label stays the same
    var displayName: String {
        switch self {
        case .movie: "Movies"
        case .tv: "TV Shows"
        case .person: "People"
        case .collection: "Collections"
        case .unknown: "Other"
        }
    }
}
