// File: RadarrMovieListItemView.swift
// Purpose: Defines RadarrMovieListItemView component for Cantinarr

import NukeUI
import SwiftUI

/// Row in the movies list showing title, runtime and quality.
struct RadarrMovieListItemView: View {
    let movie: RadarrMovie
    let qualityProfileName: String?

    // Access to services or view models might be needed for actions or more data
    // For now, just displaying passed data.

    private var formattedSizeOnDisk: String {
        guard let size = movie.sizeOnDisk, size > 0 else { return "N/A" }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useGB, .useMB]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: size)
    }

    private var formattedRuntime: String {
        guard movie.runtime > 0 else { return "N/A" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(movie.runtime * 60)) ?? "N/A"
    }

    private var availabilityStatus: (text: String, color: Color) {
        if movie.hasFile {
            return ("Downloaded", .green)
        } else if movie.monitored {
            switch movie.minimumAvailability.lowercased() {
            case "announced", "tba":
                return ("Announced", .gray)
            case "incinemas":
                return ("In Cinemas", .blue)
            case "released", "preDB": // PreDB might mean it's released and being searched for
                return ("Missing", .orange)
            default:
                return ("Monitored", .yellow)
            }
        } else {
            return ("Unmonitored", .purple)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Poster Image
            LazyImage(url: movie.posterURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if state.error != nil {
                    Color.gray.opacity(0.3) // Placeholder for error
                        .overlay(Image(systemName: "film.slash"))
                } else {
                    Color.gray.opacity(0.1) // Placeholder for loading
                        .overlay(ProgressView())
                }
            }
            .frame(width: 80, height: 120) // Typical poster aspect ratio 2:3
            .clipped()
            .cornerRadius(8)
            .shadow(radius: 3)

            // Details VStack
            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text("\(String(movie.year))")
                    Text("•")
                    Text(formattedRuntime)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                // Status and Quality Profile
                HStack(spacing: 6) {
                    Circle()
                        .fill(availabilityStatus.color)
                        .frame(width: 8, height: 8)
                    Text(availabilityStatus.text)
                        .font(.caption2)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 5)
                        .background(availabilityStatus.color.opacity(0.2))
                        .cornerRadius(4)

                    if let profileName = qualityProfileName {
                        Text(profileName)
                            .font(.caption2)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                            .lineLimit(1)
                    }
                }

                if movie.hasFile && movie.sizeOnDisk ?? 0 > 0 {
                    Text("Size: \(formattedSizeOnDisk)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer() // Pushes content to the left
        }
        .padding(10)
        .background(
            ZStack {
                LazyImage(url: movie.fanartURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 3, opaque: true) // Opaque blur
                    } else {
                        Color.clear // Fallback if no fanart
                    }
                }
                .scaleEffect(1.1) // Slightly zoom to ensure blur covers edges
                .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.75),
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.75),
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        )
        .cornerRadius(12)
        .clipped() // Ensure ZStack background clipping
        // Task to fetch quality profile name if needed, or it could be passed from ViewModel
        // .task {
        //     // Example: await fetchQualityProfileName(for: movie.qualityProfileId)
        // }
    }
}
