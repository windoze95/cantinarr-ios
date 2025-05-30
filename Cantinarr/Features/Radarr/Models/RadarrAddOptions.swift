// File: RadarrAddOptions.swift
// Purpose: Defines RadarrAddOptions component for Cantinarr

import Foundation

struct RadarrAddOptions: Codable {
    let ignoreEpisodesWithFiles: Bool? // Typically for Sonarr, but good to have a similar structure
    let ignoreEpisodesWithoutFiles: Bool?
    let searchForMovie: Bool // Radarr specific: searchForMovie instead of searchForMissingEpisodes

    init(searchForMovie: Bool) {
        ignoreEpisodesWithFiles = false // Not directly applicable to Radarr movies in this way
        ignoreEpisodesWithoutFiles = false // Not directly applicable
        self.searchForMovie = searchForMovie
    }
}
