// File: FilterManager.swift
// Purpose: Manages discover filter state for OverseerrUsers

import Foundation
import Combine

@MainActor
final class FilterManager: ObservableObject {
    @Published var selectedMedia: MediaType = .movie
    @Published var selectedProviders: Set<Int> = []
    @Published var selectedGenres: Set<Int> = []
    @Published var activeKeywordIDs: Set<Int> = []

    init() {}
}
