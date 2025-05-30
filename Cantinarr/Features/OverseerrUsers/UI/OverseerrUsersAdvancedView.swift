// File: OverseerrUsersAdvancedView.swift
// Purpose: Defines OverseerrUsersAdvancedView component for Cantinarr

import AuthenticationServices
import SwiftUI

/// Advanced search interface for Overseerr including keyword filters.
struct OverseerrUsersAdvancedView: View {
    @EnvironmentObject private var envStore: EnvironmentsStore
    @StateObject private var vm: OverseerrUsersViewModel

    @State private var isSearchLoadingLocal = false
    @State private var showingNetworkSelector = false

    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool

    // MARK: – Init

    init(viewModel: OverseerrUsersViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    // MARK: – Body

    var body: some View {
        Group {
            switch vm.authState {
            case .unknown:
                ProgressView("Checking session…")
                    .task { await vm.onAppear() } // kick the probe once
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity)

            case .unauthenticated:
                loginButton
                    .task { await vm.onAppear() } // so the view will re‑check
                // if the user backs out & returns

            case .authenticated:
                content
            }
        }
        .sheet(isPresented: $showingNetworkSelector) {
            NetworkSelectionView()
                .environmentObject(vm)
        }
    }

    // MARK: – Login Button

    private var loginButton: some View {
        VStack {
            Spacer()
            Button("Login with Plex") {
                if let s = envStore.selectedServiceInstance?
                    .decode(OverseerrSettings.self)
                {
                    vm.startPlexSSO(host: s.host, port: s.port)
                }
            }
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            Spacer()
        }
    }

    // MARK: – Main Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if vm.searchQuery.isEmpty {
                    Picker("Media", selection: $vm.filters.selectedMedia) {
                        ForEach(MediaType.allCases
                            .filter { $0 != .unknown && $0 != .person && $0 != .collection })
                        { mt in
                            Text(mt.displayName).tag(mt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if !vm.activeKeywords.isEmpty {
                        ActiveKeywordsRow(
                            keywords: vm.activeKeywords,
                            remove: { vm.remove(keywordID: $0) }
                        )
                        .padding(.top, 4)
                    }

                    SearchResultsSection(
                        isQueryEmpty: true,
                        results: vm.results,
                        isLoadingSearch: vm.isLoadingSearch,
                        isSearchLoadingLocal: isSearchLoadingLocal,
                        loadMore: { vm.loadMoreIfNeeded(current: $0, within: vm.results) }
                    )
                } else {
                    SearchResultsSection(
                        isQueryEmpty: false,
                        results: vm.results,
                        isLoadingSearch: vm.isLoadingSearch,
                        isSearchLoadingLocal: isSearchLoadingLocal,
                        loadMore: { vm.loadMoreIfNeeded(current: $0, within: vm.results) }
                    )

                    let filtered = vm.keywordSuggestions.filter { !vm.filters.activeKeywordIDs.contains($0.id) }
                    if vm.isLoadingKeywords || !filtered.isEmpty {
                        KeywordFilterListView(
                            activeKeywords: [],
                            removeKeyword: { _ in },
                            suggestions: filtered,
                            isLoadingSuggestions: vm.isLoadingKeywords,
                            chooseSuggestion: { kw in
                                searchText = ""
                                searchFieldFocused = false
                                vm.activate(keyword: kw)
                            }
                        )
                    }

                    RecommendationRowsView(
                        movieRecs: vm.movieRecs,
                        tvRecs: vm.tvRecs,
                        isLoadingMovie: vm.isLoadingMovieRecs,
                        isLoadingTv: vm.isLoadingTvRecs,
                        loadMoreMovie: vm.loadMoreMovieRecsIfNeeded,
                        loadMoreTv: vm.loadMoreTvRecsIfNeeded
                    )
                    .padding(.bottom, !vm.tvRecs.isEmpty ? 0 : 0)
                }
            }
            .padding(.top, 8)
        }
        .scrollDismissesKeyboard(.immediately)
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    searchFieldFocused = false
                    UIApplication.shared.endEditing()
                }
        )
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    searchFieldFocused = false
                    UIApplication.shared.endEditing()
                }
        )
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                SearchBarView(text: $searchText, focus: $searchFieldFocused)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty {
                            vm.clearSearchResultsAndRecs()
                            isSearchLoadingLocal = true
                        }
                        vm.searchQuery = newValue
                    }
                    .onChange(of: vm.isLoadingSearch) { loading in
                        if !loading {
                            isSearchLoadingLocal = false
                        }
                    }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Subviews

private struct ActiveKeywordsRow: View {
    let keywords: [Keyword]
    let remove: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(keywords, id: \.id) { kw in
                    HStack(spacing: 4) {
                        Text(kw.name).font(.caption)
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .onTapGesture { remove(kw.id) }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.25)))
                    .foregroundColor(Color.accentColor)
                }
            }
            .padding(.horizontal)
            .frame(height: 32)
        }
    }
}

private struct SearchResultsSection: View {
    let isQueryEmpty: Bool
    let results: [OverseerrUsersViewModel.MediaItem]
    let isLoadingSearch: Bool
    let isSearchLoadingLocal: Bool
    let loadMore: (OverseerrUsersViewModel.MediaItem) -> Void

    var body: some View {
        Group {
            if isQueryEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)]) {
                    ForEach(results) { item in
                        MediaCardView(id: item.id,
                                      mediaType: item.mediaType,
                                      title: item.title,
                                      posterPath: item.posterPath)
                            .onAppear { loadMore(item) }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                Text("Search Results")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    if (isSearchLoadingLocal || isLoadingSearch) && results.isEmpty {
                        HorizontalItemRow(items: [MediaItem](), isLoading: true, onAppear: { _ in }) { _ in
                            MediaCardView(id: 0, mediaType: .movie, title: "", posterPath: nil)
                                .frame(width: 110)
                        } placeholder: {
                            LoadingCardView()
                        }
                        .frame(height: 180)
                    } else if !isSearchLoadingLocal && !isLoadingSearch && results.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No results found")
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(height: 160)
                    } else {
                        HorizontalItemRow(
                            items: results,
                            isLoading: isLoadingSearch,
                            onAppear: { item in loadMore(item) }
                        ) { item in
                            MediaCardView(id: item.id,
                                          mediaType: item.mediaType,
                                          title: item.title,
                                          posterPath: item.posterPath)
                                .frame(width: 110)
                        } placeholder: {
                            LoadingCardView()
                        }
                    }
                }
            }
        }
    }
}

private struct KeywordFilterListView: View {
    let activeKeywords: [Keyword]
    let removeKeyword: (Int) -> Void
    let suggestions: [Keyword]
    let isLoadingSuggestions: Bool
    let chooseSuggestion: (Keyword) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !activeKeywords.isEmpty {
                ActiveKeywordsRow(keywords: activeKeywords, remove: removeKeyword)
            }
            if isLoadingSuggestions || !suggestions.isEmpty {
                Text("Search by Keyword")
                    .font(.headline)
                    .padding(.horizontal)
                if isLoadingSuggestions {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0 ..< 5, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 32)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if !suggestions.isEmpty {
                    KeywordSuggestionRow(keywords: suggestions, choose: chooseSuggestion)
                }
            }
        }
    }
}

private struct RecommendationRowsView: View {
    let movieRecs: [OverseerrUsersViewModel.MediaItem]
    let tvRecs: [OverseerrUsersViewModel.MediaItem]
    let isLoadingMovie: Bool
    let isLoadingTv: Bool
    let loadMoreMovie: (OverseerrUsersViewModel.MediaItem) -> Void
    let loadMoreTv: (OverseerrUsersViewModel.MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !movieRecs.isEmpty {
                Text("Movies you might like")
                    .font(.headline)
                    .padding(.horizontal)
                HorizontalItemRow(
                    items: movieRecs,
                    isLoading: isLoadingMovie,
                    onAppear: { item in loadMoreMovie(item) }
                ) { item in
                    MediaCardView(id: item.id,
                                  mediaType: item.mediaType,
                                  title: item.title,
                                  posterPath: item.posterPath)
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
            }
            if !tvRecs.isEmpty {
                Text("Shows you might like")
                    .font(.headline)
                    .padding(.horizontal)
                HorizontalItemRow(
                    items: tvRecs,
                    isLoading: isLoadingTv,
                    onAppear: { item in loadMoreTv(item) }
                ) { item in
                    MediaCardView(id: item.id,
                                  mediaType: item.mediaType,
                                  title: item.title,
                                  posterPath: item.posterPath)
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
            }
        }
    }
}

#if DEBUG
    struct SearchResultsSection_Previews: PreviewProvider {
        static let sampleItem = OverseerrUsersViewModel.MediaItem(
            id: 1,
            title: "Sample",
            posterPath: nil,
            mediaType: .movie
        )
        static var previews: some View {
            Group {
                SearchResultsSection(isQueryEmpty: false,
                                     results: [],
                                     isLoadingSearch: true,
                                     isSearchLoadingLocal: true,
                                     loadMore: { _ in })
                    .previewDisplayName("Loading")
                SearchResultsSection(isQueryEmpty: false,
                                     results: [],
                                     isLoadingSearch: false,
                                     isSearchLoadingLocal: false,
                                     loadMore: { _ in })
                    .previewDisplayName("Empty")
                SearchResultsSection(isQueryEmpty: false,
                                     results: [sampleItem, sampleItem],
                                     isLoadingSearch: false,
                                     isSearchLoadingLocal: false,
                                     loadMore: { _ in })
                    .previewDisplayName("Results")
                SearchResultsSection(isQueryEmpty: true,
                                     results: [sampleItem, sampleItem],
                                     isLoadingSearch: false,
                                     isSearchLoadingLocal: false,
                                     loadMore: { _ in })
                    .previewDisplayName("Grid Results")
            }
            .previewLayout(.sizeThatFits)
        }
    }
#endif
// --------------------------------------------------
//  Plex SSO presentation helper (unchanged)
// --------------------------------------------------
class OverseerrAuthHelper: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OverseerrAuthHelper()
    override private init() {}

    private var session: ASWebAuthenticationSession?
    weak var delegate: OverseerrPlexSSODelegate?

    func startPlexLogin(url: URL) {
        let s = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: nil
        ) { callbackURL, error in
            guard
                error == nil,
                let callbackURL = callbackURL,
                let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                let token = comps.queryItems?.first(where: { $0.name == "token" })?.value
            else {
                print("⚠️ Plex SSO failed: \(error?.localizedDescription ?? "no token")")
                return
            }
            DispatchQueue.main.async {
                self.delegate?.didReceivePlexToken(token)
            }
        }
        s.presentationContextProvider = self
        s.prefersEphemeralWebBrowserSession = true
        session = s
        s.start()
    }

    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive }
            .flatMap { $0 as? UIWindowScene }
        return windowScene?.windows.first(where: { $0.isKeyWindow }) ?? UIWindow()
    }
}
