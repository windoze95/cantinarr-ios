// File: MediaCardView.swift
// Purpose: Defines MediaCardView component for Cantinarr

import NukeUI
import Nuke
import SwiftUI

struct MediaCardView: View, Equatable {
    let id: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?

    @EnvironmentObject private var envStore: EnvironmentsStore

    // MARK: – Image helper

    private var posterURL: URL? {
        guard let path = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w300\(path)")
    }

    // MARK: – Body

    var body: some View {
        if let settings = envStore.selectedServiceInstance?
            .decode(OverseerrSettings.self)
        {
            NavigationLink {
                MediaDetailView(
                    id: id,
                    mediaType: mediaType,
                    service: OverseerrAPIService(settings: settings)
                )
            } label: {
                posterAndTitle
            }
            .buttonStyle(.plain)
        } else {
            // No service selected ➜ show the card but disable navigation
            posterAndTitle
                .opacity(0.6)
        }
    }

    // MARK: – Poster + title

    @ViewBuilder
    private var posterAndTitle: some View {
        VStack(spacing: 8) {
            if let url = posterURL {
                LazyImage(
                    request: ImageRequest(
                        url: url,
                        processors: [
                            ImageProcessors.Resize(
                                size: CGSize(width: 100, height: 150),
                                unit: .points
                            )
                        ]
                    )
                ) { state in
                    if let img = state.image {
                        img.resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else if state.error != nil {
                        Color.gray.opacity(0.2)
                    } else {
                        ZStack {
                            Color.gray.opacity(0.2)
                            ProgressView()
                        }
                    }
                }
                .frame(height: 150)
                .clipped()
                .cornerRadius(8)
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: 150)
                    .cornerRadius(8)
            }

            Text(title)
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    static func == (lhs: MediaCardView, rhs: MediaCardView) -> Bool {
        lhs.id == rhs.id &&
        lhs.mediaType == rhs.mediaType &&
        lhs.title == rhs.title &&
        lhs.posterPath == rhs.posterPath
    }
}
