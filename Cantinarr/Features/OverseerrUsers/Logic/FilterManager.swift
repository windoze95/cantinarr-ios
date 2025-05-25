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

    private var cancellables = Set<AnyCancellable>()

    private let settingsKey: String
    private var storageKey: String { "discoverFilters-\(settingsKey)" }

    init(settingsKey: String) {
        self.settingsKey = settingsKey

        $selectedMedia
            .dropFirst()
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)

        $selectedProviders
            .dropFirst()
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)

        $selectedGenres
            .dropFirst()
            .sink { [weak self] _ in self?.save() }
            .store(in: &cancellables)
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(SavedFilters.self, from: data)
        else { return }
        selectedMedia = saved.mediaType
        selectedProviders = Set(saved.providerIds)
        selectedGenres = Set(saved.genreIds)
    }

    func save() {
        let saved = SavedFilters(
            mediaType: selectedMedia,
            providerIds: Array(selectedProviders),
            genreIds: Array(selectedGenres)
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private struct SavedFilters: Codable {
        let mediaType: MediaType
        let providerIds: [Int]
        let genreIds: [Int]
    }
}
