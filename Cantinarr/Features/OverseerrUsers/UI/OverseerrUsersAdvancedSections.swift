// File: OverseerrUsersAdvancedSections.swift
// Purpose: Subviews for OverseerrUsersAdvancedView

import SwiftUI

// MARK: - Search Bar & Results

struct OverseerrSearchBarResultsView<KeywordList: View, Recs: View>: View {
    let hasActiveKeywords: Bool
    var vm: OverseerrUsersViewModel
@ViewBuilder var keywordList: () -> KeywordList
@ViewBuilder var recRows: () -> Recs
    @Binding var searchText: String
    var searchQuery: String
    @Binding var selectedMedia: MediaType
    let results: [OverseerrUsersViewModel.MediaItem]
    let isLoadingSearch: Bool
    @Binding var isSearchLoadingLocal: Bool
    var loadMore: (OverseerrUsersViewModel.MediaItem) -> Void

    @FocusState var searchFieldFocused: Bool
    let onSearchQueryChange: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if searchQuery.isEmpty {
                    Picker("Media", selection: $selectedMedia) {
                        ForEach(MediaType.allCases.filter { $0 != .unknown && $0 != .person && $0 != .collection }) { mt in
                            Text(mt.displayName).tag(mt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    if hasActiveKeywords {
                        ActiveKeywordsView()
                            .environmentObject(vm)
                            .padding(.top, 4)
                    }

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
                            HorizontalMediaRow(items: [], isLoading: true) { _ in }
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
                            HorizontalMediaRow(
                                items: results,
                                isLoading: isLoadingSearch
                            ) { item in
                                loadMore(item)
                            }
                        }
                    }
                    keywordList()
                    recRows()
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
                            isSearchLoadingLocal = true
                        }
                        onSearchQueryChange(newValue)
                    }
                    .onChange(of: isLoadingSearch) { loading in
                        if !loading {
                            isSearchLoadingLocal = false
                        }
                    }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Keyword Filter List

struct OverseerrKeywordFilterListView: View {
    let keywords: [OverseerrAPIService.Keyword]
    let isLoading: Bool
    @Binding var searchText: String
    @FocusState.Binding var searchFieldFocused: Bool
    let choose: (OverseerrAPIService.Keyword) -> Void

    var body: some View {
        if isLoading {
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
        } else if !keywords.isEmpty {
            KeywordSuggestionRow(keywords: keywords) { kw in
                searchText = ""
                searchFieldFocused = false
                choose(kw)
            }
        }
    }
}

// MARK: - Recommendation Rows

struct OverseerrRecommendationRowsView: View {
    let movieRecs: [OverseerrUsersViewModel.MediaItem]
    let tvRecs: [OverseerrUsersViewModel.MediaItem]
    let isLoadingMovieRecs: Bool
    let isLoadingTvRecs: Bool
    let loadMoreMovie: (OverseerrUsersViewModel.MediaItem) -> Void
    let loadMoreTv: (OverseerrUsersViewModel.MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !movieRecs.isEmpty {
                Text("Movies you might like")
                    .font(.headline)
                    .padding(.horizontal)
                HorizontalMediaRow(items: movieRecs, isLoading: isLoadingMovieRecs) { item in
                    loadMoreMovie(item)
                }
            }
            if !tvRecs.isEmpty {
                Text("Shows you might like")
                    .font(.headline)
                    .padding(.horizontal)
                HorizontalMediaRow(items: tvRecs, isLoading: isLoadingTvRecs) { item in
                    loadMoreTv(item)
                }
                .padding(.bottom)
            }
        }
    }
}

#if DEBUG
struct OverseerrSearchBarResultsView_Previews: PreviewProvider {
    static var sampleItem = OverseerrUsersViewModel.MediaItem(id: 1, title: "Sample", posterPath: nil, mediaType: .movie)
    @State static var query = ""
    @State static var selected: MediaType = .movie
    @State static var loadingLocal = false

    static var previews: some View {
        Group {
            OverseerrSearchBarResultsView(keywordList: { EmptyView() }, recRows: { EmptyView() },
                searchText: $query,
                searchQuery: "",
                selectedMedia: $selected,
                results: [sampleItem, sampleItem],
                isLoadingSearch: false,
                isSearchLoadingLocal: $loadingLocal,
                loadMore: { _ in },
                searchFieldFocused: .constant(false),
                onSearchQueryChange: { _ in }
            )
            .previewDisplayName("Grid")

            OverseerrSearchBarResultsView(keywordList: { EmptyView() }, recRows: { EmptyView() },
                searchText: $query,
                searchQuery: "Avengers",
                selectedMedia: $selected,
                results: [],
                isLoadingSearch: true,
                isSearchLoadingLocal: $loadingLocal,
                loadMore: { _ in },
                searchFieldFocused: .constant(false),
                onSearchQueryChange: { _ in }
            )
            .previewDisplayName("Loading")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif

