import NukeUI
import SwiftUI

struct MediaCardView: View {
    let id: Int
    let mediaType: MediaType
    let title: String
    let posterPath: String?

    @EnvironmentObject private var envStore: EnvironmentsStore
    @EnvironmentObject private var userSession: UserSession

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
                    service: OverseerrAPIService(settings: settings),
                    userSession: userSession
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
                LazyImage(url: url) { state in
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
}
