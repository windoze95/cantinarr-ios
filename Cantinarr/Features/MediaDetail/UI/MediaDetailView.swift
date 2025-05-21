// File: MediaDetailView.swift
// Purpose: Defines MediaDetailView component for Cantinarr

import NukeUI
import SwiftUI

// helper to pass the tagline’s runtime height up the view tree
private struct TaglineHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MediaDetailView: View {
    @StateObject private var vm: MediaDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // keep the measured height here
    @State private var taglineHeight: CGFloat = .zero

    init(id: Int,
         mediaType: MediaType,
         service: OverseerrAPIService,
         userSession: UserSession)
    {
        _vm = StateObject(
            wrappedValue: MediaDetailViewModel(
                id: id,
                mediaType: mediaType,
                service: service,
                userSession: userSession
            )
        )
    }

    // MARK: – Global blurred background

    @ViewBuilder
    private var blurredBackground: some View {
        if let url = vm.backdropURL {
            LazyImage(url: url) { state in
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
            blurredBackground
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
                    // measured once, then stays constant
                    Text(vm.tagline ?? "")
                        .font(.title3.italic())
                        .opacity(0.8)
                        .background(GeometryReader { tgGeo in
                            Color.clear
                                .preference(key: TaglineHeightKey.self,
                                            value: tgGeo.size.height)
                        })

                    Text(vm.overview).font(.body)

                    if vm.mediaType != .movie {
                        seasonGrid
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
        }
        // remove any nav-bar
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        // let every pixel be used
        .ignoresSafeArea(edges: .top)
    }

    // MARK: – header (unchanged except the removed fixed height)

    @ViewBuilder private var header: some View {
        ZStack(alignment: .bottomLeading) {
            // gradient bottom fade
            LinearGradient(
                colors: [Color.black.opacity(0.6), Color.clear],
                startPoint: .bottom, endPoint: .top
            )
            // poster + meta
            HStack(alignment: .bottom, spacing: 16) {
                if let p = vm.posterURL {
                    LazyImage(url: p) { state in
                        state.image?.resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 180)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.title)
                        .font(.title.weight(.semibold))
                        .lineLimit(3) // ← wrap to two lines max
                        .truncationMode(.tail) //   and add … if it’s still too long
                    Label(vm.availability.label, systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(vm.availability.tint)
                        .cornerRadius(6)
                    buttonRow
                }
                Spacer()
            }
            .padding()
        }
        // 3️⃣ NEW — backdrop is decoration, so it can’t stretch the layout
        .background {
            if let url = vm.backdropURL {
                LazyImage(url: url) { state in
                    state.image?
                        .resizable()
                        .scaledToFill() // may overflow horizontally…
                        .overlay(Color.black.opacity(0.25))
                }
            }
        }
        .clipped()
    }

    /// Primary + secondary CTA row
    @ViewBuilder private var buttonRow: some View {
        VStack(alignment: .center, spacing: 10) { // VStack for two rows
            // First Row: Trailer and Request (if applicable)
            HStack(spacing: 12) {
                // "Watch Trailer" button - always shown
                watchTrailerBtn
                    .frame(maxWidth: .infinity)
            }
            // "Report" button - shown if at least partially available
            if vm.availability == .available || vm.availability == .partiallyAvailable {
                reportBtn
            }
        }
    }

    // MARK: – buttons

    private var watchTrailerBtn: some View {
        Button {
            if vm.trailerVideoID != nil {
                vm.showTrailerPlayer = true
            } else {
                // Fallback: If no video ID, open YouTube search for the title + "trailer"
                // Ensure title is not empty
                guard !vm.title.isEmpty,
                      let query = "\(vm.title) trailer".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let url = URL(string: "https://www.youtube.com/results?search_query=\(query)")
                else {
                    print("⚠️ Could not form YouTube search URL for title: \(vm.title)")
                    return
                }
                UIApplication.shared.open(url)
            }
        } label: {
            Label("Watch Trailer", systemImage: "video")
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $vm.showTrailerPlayer) {
            if let embedURL = vm.youtubeEmbedURL {
                TrailerPlayerView(url: embedURL)
            } else {
                // Fallback if URL is somehow nil when sheet is shown (should be rare)
                VStack {
                    Text("Trailer is unavailable at the moment.")
                    Button("Dismiss") { vm.showTrailerPlayer = false }
                        .padding()
                }
            }
        }
    }

    private var reportBtn: some View {
        Button {
            showReport.toggle()
        } label: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .buttonStyle(.bordered)
        .tint(.yellow)
        .sheet(isPresented: $showReport) { ReportIssueSheet(vm: vm) }
    }

    private var settingsBtn: some View {
        Button {
            showManage.toggle()
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showManage) { ManageMediaSheet(mediaID: vm.id) }
    }

    @State private var showReport = false
    @State private var showManage = false

    // Only show season grid for TV shows
    @ViewBuilder private var seasonGrid: some View {
        if vm.mediaType == .tv { // Check mediaType
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)]) {
                ForEach(vm.seasons) { s in
                    VStack(spacing: 4) {
                        Text("Season \(s.seasonNumber)")
                        Text("\(s.episodeCount) eps").font(.caption).foregroundColor(.secondary)
                        Label(s.mediaInfo?.status.label ?? "–", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(s.mediaInfo?.status.tint ?? .gray)
                            .cornerRadius(4)
                    }
                    .padding(8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        if s.mediaInfo?.status != .available {
                            Task { try? await vm.request() } // This might need more specific request logic for seasons
                        }
                    }
                }
            }
        }
    }

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
