// File: FilterManager.swift
// Purpose: Manages discover filter state for OverseerrUsers

// This file relies on Combine which is only available on Apple platforms.
// Guard its contents so the package can compile on Linux.
#if canImport(Combine)
import Combine
import Foundation

@MainActor
final class FilterManager: ObservableObject {
    @Published var selectedMedia: MediaType = .movie
    @Published var selectedProviders: Set<Int> = []
    @Published var selectedGenres: Set<Int> = []
    @Published var activeKeywordIDs: Set<Int> = []

    init() {}
}
#endif
