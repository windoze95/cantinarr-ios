// File: MediaDetailView.swift
// Purpose: Defines MediaDetailView component for Cantinarr

import NukeUI
import SwiftUI

struct MediaDetailView: View {
    @StateObject private var vm: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // keep the measured height here
    @State private var taglineHeight: CGFloat = .zero

    init(id: Int,
         mediaType: MediaType,
         service: OverseerrServiceType)
    {
        _vm = StateObject(
            wrappedValue: MediaDetailViewModel(
                id: id,
                mediaType: mediaType,
                service: service
            )
        )
    }

    // MARK: – Global blurred background

    @ViewBuilder
    private func blurredBackground(size: CGSize) -> some View {
        if let url = vm.backdropURL {
            LazyImage(
                request: ImageRequest(
                    url: url,
                    processors: [ImageProcessors.Resize(size: size, unit: .points)]
                )
            ) { state in
                state.image?
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
            }
            .overlay(Color.black.opacity(0.4))
            .ignoresSafeArea() // full‑screen incl. safe areas
        } else {
            Color.black.opacity(0.6).ignoresSafeArea()
        }
    }

    var body: some View {
        GeometryReader { rootGeo in
            blurredBackground(size: rootGeo.size)
            // Safe width & height the content is allowed to use
            let safeWidth = rootGeo.size.width
                - rootGeo.safeAreaInsets.leading
                - rootGeo.safeAreaInsets.trailing
            let safeHeight = rootGeo.size.height
                - rootGeo.safeAreaInsets.bottom

            ScrollView(.vertical, showsIndicators: false) {
                let headerMax = max(0, safeHeight - 100 - taglineHeight) // never < 0
                let headerMin = max(44, safeWidth - 200) // ≥ nav‑bar height

                ShrinkOnScrollHeader(
                    maxHeight: headerMax,
                    minHeight: headerMin
                ) {
                    header
                        .frame(width: safeWidth, alignment: .leading)
                }
                .frame(width: safeWidth, // only the safe-area width is shown
                       alignment: .leading)
                .clipped()

                // CONTENT
                VStack(alignment: .leading, spacing: 16) {
                    if !vm.tagline.isEmpty {
                        MediaTaglineView(tagline: vm.tagline)
                    }

                    MediaOverviewView(overview: vm.overview)

                    if vm.mediaType != .movie {
                        SeasonGridView(seasons: vm.seasons) {
                            Task { try? await vm.request() }
                        }
                    }
                }
                .frame(maxWidth: safeWidth, alignment: .leading)
                .padding()
            }
            .coordinateSpace(name: "scroll")
            .overlay(alignment: .topTrailing) { closeButton.padding(.top, 44) }
            .onPreferenceChange(TaglineHeightKey.self) { taglineHeight = $0 }
            .task { await vm.load() }
            .alert("Error",
                   isPresented: .constant(vm.error != nil),
                   actions: { Button("Dismiss") { vm.error = nil } },
                   message: { Text(vm.error ?? "") })
            .sheet(isPresented: $showReport) { ReportIssueSheet(vm: vm) }
        }
        // remove any nav-bar
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        // let every pixel be used
        .ignoresSafeArea(edges: .top)
    }

    // MARK: – header

    @ViewBuilder private var header: some View {
        MediaHeaderView(
            posterURL: vm.posterURL,
            backdropURL: vm.backdropURL,
            title: vm.title,
            availability: vm.availability,
            trailerVideoID: vm.trailerVideoID,
            youtubeEmbedURL: vm.youtubeEmbedURL,
            showTrailerPlayer: $vm.showTrailerPlayer,
            showReport: $showReport
        )
    }

    @State private var showReport = false

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2).padding().foregroundColor(.secondary)
        }
    }

    private struct ShrinkOnScrollHeader<Content: View>: View {
        let maxHeight: CGFloat
        let minHeight: CGFloat
        @ViewBuilder var content: Content

        var body: some View {
            GeometryReader { g in
                let safeMin = max(0, minHeight)
                let safeMax = max(safeMin, maxHeight)
                let offset = g.frame(in: .named("scroll")).minY
                let height = max(safeMin, safeMax - offset)

                content
                    .frame(width: g.size.width, height: height)
                    .clipped()
                    .offset(y: offset < 0 ? -offset : 0)
            }
            .frame(height: max(0, maxHeight))
        }
    }
}

struct TrailerPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView { // Or just VStack if you don't need a nav bar in the sheet
            WebView(url: url)
                .edgesIgnoringSafeArea(.all) // Let the webview take full space
                .navigationTitle("Trailer")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { // Or .navigationBarTrailing
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

extension UINavigationController: UIGestureRecognizerDelegate {
    /// Enables the interactive pop gesture after the navigation controller loads.
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    /// Allows the swipe‑to‑go‑back gesture only when the stack has more than one view.
    public func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}
