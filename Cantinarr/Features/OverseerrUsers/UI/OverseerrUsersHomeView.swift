// File: OverseerrUsersHomeView.swift
// Purpose: Defines OverseerrUsersHomeView component for Cantinarr

import AuthenticationServices
import Combine
import SwiftUI

/// Displays trending media and search for authenticated Overseerr users.
struct OverseerrUsersHomeView: View {
    // dependencies
    @EnvironmentObject private var envStore: EnvironmentsStore
    @ObservedObject private var vm: TrendingViewModel // Changed to ObservedObject as it's passed in
    @ObservedObject private var overseerrUsersVM: OverseerrUsersViewModel // Changed to ObservedObject

    @State private var searchText = ""
    @FocusState private var searchFieldFocused: Bool
    @State private var isSearchLoadingLocal = false

    // MARK: – Init

    init(trendingVM: TrendingViewModel,
         overseerrUsersVM: OverseerrUsersViewModel)
    {
        // _vm and _overseerrUsersVM are initialized by the @ObservedObject property wrapper
        // when the view is created and these objects are passed in.
        // We assign them directly.
        vm = trendingVM
        self.overseerrUsersVM = overseerrUsersVM
    }

    var body: some View {
        // This view is now only expected to be shown when authenticated.
        // The authState check might be redundant if HomeEntry guarantees it,
        // but keeping it adds robustness.
        switch overseerrUsersVM.authState {
        case .authenticated:
            authenticatedContent
        default:
            // Should not happen if HomeEntry works correctly, but show progress as fallback.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await overseerrUsersVM.onAppear() } // Retry auth check if somehow reached here
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        // Check for critical errors first (e.g., failure to load providers prevents core functionality)
        // Show a *contained* error view if basics fail, replacing the normal content.
        if let basicError = overseerrUsersVM.connectionError, overseerrUsersVM.watchProviders.isEmpty {
            basicErrorView(error: basicError)
        } else {
            // Main scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Display less critical connection error from VM *if* it exists,
                    // but allow content below if possible. User can dismiss.
                    if let transientError = overseerrUsersVM.connectionError, !overseerrUsersVM.watchProviders.isEmpty {
                        inlineErrorBanner(error: transientError)
                    }

                    // Show Trending or Search Results based on searchText
                    if searchText.isEmpty {
                        trendingSection // Handles its own errors/loading/empty states internally
                    } else {
                        searchResultsSection // Handles its own errors/loading/empty states internally
                    }
                }
                .padding(.vertical, 8) // Padding for the overall VStack content
            }
            // Pinned Search Bar at the top
            .safeAreaInset(edge: .top) {
                SearchBarView(text: $searchText, focus: $searchFieldFocused)
                    .padding(.horizontal) // Standard padding for the bar itself
                    .padding(.top, 8) // Padding above search bar
                    .padding(.bottom, 4) // Padding below search bar
                    .onChange(of: searchText) { new in
                        // When search text changes, update the ViewModel
                        if !new.isEmpty && overseerrUsersVM.searchQuery.isEmpty {
                            // Clear stale results immediately when starting a new search
                            overseerrUsersVM.clearSearchResultsAndRecs()
                        }
                        overseerrUsersVM.searchQuery = new
                        isSearchLoadingLocal = !new.isEmpty // Show local shimmer immediately
                    }
                    .onChange(of: overseerrUsersVM.isLoadingSearch) { loading in
                        // When actual search finishes, stop local shimmer
                        if !loading {
                            isSearchLoadingLocal = false
                        }
                    }
                    .background(.ultraThinMaterial) // Background for the search bar area
            }
            // Synchronize searchText with overseerrUsersVM.searchQuery if it can be cleared externally
            .onChange(of: overseerrUsersVM.searchQuery) { newQuery in
                if searchText != newQuery {
                    searchText = newQuery
                }
            }
            .navigationBarTitleDisplayMode(.inline) // Keep nav bar compact
            // Task to load initial data specific to this view (Trending)
            .task {
                if vm.items.isEmpty && vm.connectionError == nil { // Only load if empty and no prior error
                    await vm.bootstrap()
                }
                // Check if basics are loaded (might be redundant with HomeEntry's task)
                if overseerrUsersVM.watchProviders.isEmpty && overseerrUsersVM.connectionError == nil {
                    await overseerrUsersVM.loadAllBasics()
                }
            }
            .scrollDismissesKeyboard(.immediately)
            // Dismiss keyboard on tap outside search bar
            .contentShape(Rectangle()) // Make the whole scroll view tappable
            .onTapGesture {
                searchFieldFocused = false
                UIApplication.shared.endEditing()
            }
        }
    }

    // View for critical basic load errors (replaces whole view)
    @ViewBuilder
    private func basicErrorView(error: String) -> some View {
        VStack(spacing: 15) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundColor(.orange)
            Text("Service Configuration Error")
                .font(.title3)
                .fontWeight(.semibold)
            Text(error)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") {
                Task {
                    await overseerrUsersVM.loadAllBasics() // Attempt to reload basic config
                    // If basics succeed, other content might load via .task
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    // View for less critical inline errors (shown above content)
    @ViewBuilder
    private func inlineErrorBanner(error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(error)
                .font(.caption)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading) // Allow text to take space
            Button {
                overseerrUsersVM.connectionError = nil // Allow user to dismiss transient errors
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Dismiss error")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
        .padding(.horizontal)
        .transition(.opacity.combined(with: .move(edge: .top))) // Nice transition
        .animation(.default, value: error)
    }

    @ViewBuilder
    private var trendingSection: some View {
        TrendingDisplayView(
            items: vm.items,
            isLoading: vm.isLoading,
            connectionError: vm.connectionError,
            loadMore: { item in vm.loadMoreIfNeeded(current: item) },
            retry: { Task { await vm.bootstrap() } }
        )
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        // Filter out suggestions that are already active keywords
        let filteredSuggestions = overseerrUsersVM.keywordSuggestions
            .filter { !overseerrUsersVM.filters.activeKeywordIDs.contains($0.id) }

        SearchResultsRowView(
            results: overseerrUsersVM.results,
            isLoading: overseerrUsersVM.isLoadingSearch,
            showLocalLoading: isSearchLoadingLocal,
            searchText: searchText,
            loadMore: { item in
                overseerrUsersVM.loadMoreIfNeeded(current: item,
                                                  within: overseerrUsersVM.results)
            }
        )

        KeywordSuggestionsRowView(
            keywords: filteredSuggestions,
            isLoading: overseerrUsersVM.isLoadingKeywords
        ) { kw in
            overseerrUsersVM.activate(keyword: kw)
            searchFieldFocused = false
            UIApplication.shared.endEditing()
        }

        // ** Recommendations Section **
        VStack(alignment: .leading, spacing: 16) { // Group recommendations
            // Movie Recommendations
            if overseerrUsersVM.isLoadingMovieRecs && overseerrUsersVM.movieRecs.isEmpty {
                Text("Movies You Might Like").font(.headline).padding(.horizontal).opacity(0) // Placeholder title
                HorizontalItemRow(items: [MediaItem](), isLoading: true, onAppear: { _ in }) { _ in
                    MediaCardView(id: 0, mediaType: .movie, title: "", posterPath: nil)
                        .equatable()
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
                .frame(height: 200)
            } else if !overseerrUsersVM.movieRecs.isEmpty {
                Text("Movies You Might Like")
                    .font(.headline).padding(.horizontal)
                HorizontalItemRow(
                    items: overseerrUsersVM.movieRecs,
                    isLoading: overseerrUsersVM.isLoadingMovieRecs,
                    onAppear: { item in overseerrUsersVM.loadMoreMovieRecsIfNeeded(current: item) }
                ) { item in
                    MediaCardView(id: item.id,
                                  mediaType: item.mediaType,
                                  title: item.title,
                                  posterPath: item.posterPath)
                        .equatable()
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
            }

            // TV Recommendations
            if overseerrUsersVM.isLoadingTvRecs && overseerrUsersVM.tvRecs.isEmpty {
                Text("Shows You Might Like").font(.headline).padding(.horizontal).opacity(0) // Placeholder title
                HorizontalItemRow(items: [MediaItem](), isLoading: true, onAppear: { _ in }) { _ in
                    MediaCardView(id: 0, mediaType: .movie, title: "", posterPath: nil)
                        .equatable()
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
                .frame(height: 200)
            } else if !overseerrUsersVM.tvRecs.isEmpty {
                Text("Shows You Might Like")
                    .font(.headline).padding(.horizontal)
                HorizontalItemRow(
                    items: overseerrUsersVM.tvRecs,
                    isLoading: overseerrUsersVM.isLoadingTvRecs,
                    onAppear: { item in overseerrUsersVM.loadMoreTvRecsIfNeeded(current: item) }
                ) { item in
                    MediaCardView(id: item.id,
                                  mediaType: item.mediaType,
                                  title: item.title,
                                  posterPath: item.posterPath)
                        .equatable()
                        .frame(width: 110)
                } placeholder: {
                    LoadingCardView()
                }
            }
        }
        .padding(.bottom) // Add padding at the end of the scroll content if recs are shown
    }
}

// MARK: - Subviews

private struct TrendingDisplayView: View {
    let items: [MediaItem]
    let isLoading: Bool
    let connectionError: String?
    let loadMore: (MediaItem) -> Void
    let retry: () -> Void

    var body: some View {
        if let error = connectionError {
            VStack {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("Cannot Load Trending")
                    .font(.headline)
                    .padding(.bottom, 2)
                Text(error)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("Retry", action: retry)
                    .buttonStyle(.bordered)
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            .padding()
        } else if items.isEmpty && isLoading {
            Text("Trending")
                .font(.title2)
                .padding(.horizontal)
                .opacity(0)
            HorizontalItemRow(items: [MediaItem](), isLoading: true, onAppear: { _ in }) { _ in
                MediaCardView(id: 0, mediaType: .movie, title: "", posterPath: nil)
                    .equatable()
                    .frame(width: 110)
            } placeholder: {
                LoadingCardView()
            }
            .frame(height: 200)
        } else if !items.isEmpty {
            Text("Trending")
                .font(.title2)
                .padding(.horizontal)
            HorizontalItemRow(items: items, isLoading: isLoading, onAppear: { item in
                loadMore(item)
            }) { item in
                MediaCardView(id: item.id,
                              mediaType: item.mediaType,
                              title: item.title,
                              posterPath: item.posterPath)
                    .equatable()
                    .frame(width: 110)
            } placeholder: {
                LoadingCardView()
            }
        } else {
            Text("Trending")
                .font(.title2)
                .padding(.horizontal)
            Text("No trending items found.")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
        }
    }
}

private struct SearchResultsRowView: View {
    let results: [MediaItem]
    let isLoading: Bool
    let showLocalLoading: Bool
    let searchText: String
    let loadMore: (MediaItem) -> Void

    var body: some View {
        if (showLocalLoading || isLoading) && results.isEmpty {
            Text("Search Results")
                .font(.headline)
                .padding(.horizontal)
                .opacity(0)
            HorizontalItemRow(items: [MediaItem](), isLoading: true, onAppear: { _ in }) { _ in
                MediaCardView(id: 0, mediaType: .movie, title: "", posterPath: nil)
                    .equatable()
                    .frame(width: 110)
            } placeholder: {
                LoadingCardView()
            }
            .frame(height: 200)
        } else if !showLocalLoading && !isLoading && results.isEmpty && !searchText.isEmpty {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No results found for \"\(searchText)\"")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .frame(height: 160)
            .padding(.horizontal)
        } else if !results.isEmpty {
            Text("Search Results")
                .font(.headline)
                .padding(.horizontal)
            HorizontalItemRow(items: results, isLoading: isLoading, onAppear: { item in
                loadMore(item)
            }) { item in
                MediaCardView(id: item.id,
                              mediaType: item.mediaType,
                              title: item.title,
                              posterPath: item.posterPath)
                    .equatable()
                    .frame(width: 110)
            } placeholder: {
                LoadingCardView()
            }
        }
    }
}

private struct KeywordSuggestionsRowView: View {
    let keywords: [Keyword]
    let isLoading: Bool
    let choose: (Keyword) -> Void

    var body: some View {
        if isLoading {
            Text("Search by Keyword")
                .font(.headline)
                .padding(.horizontal)
                .opacity(0)
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
            .frame(height: 40)
        } else if !keywords.isEmpty {
            Text("Search by Keyword")
                .font(.headline)
                .padding(.horizontal)
            KeywordSuggestionRow(keywords: keywords, choose: choose)
        }
    }
}

#if DEBUG
    struct TrendingDisplayView_Previews: PreviewProvider {
        static let sampleItem = MediaItem(
            id: 1,
            title: "Sample",
            posterPath: nil,
            mediaType: .movie
        )
        static var previews: some View {
            Group {
                TrendingDisplayView(items: [], isLoading: true, connectionError: nil, loadMore: { _ in }, retry: {})
                    .previewDisplayName("Loading")
                TrendingDisplayView(items: [], isLoading: false, connectionError: nil, loadMore: { _ in }, retry: {})
                    .previewDisplayName("Empty")
                TrendingDisplayView(
                    items: [sampleItem, sampleItem],
                    isLoading: false,
                    connectionError: nil,
                    loadMore: { _ in },
                    retry: {}
                )
                .previewDisplayName("Populated")
            }
            .previewLayout(.sizeThatFits)
        }
    }

    struct SearchResultsRowView_Previews: PreviewProvider {
        static let sampleItem = TrendingDisplayView_Previews.sampleItem
        static var previews: some View {
            Group {
                SearchResultsRowView(
                    results: [],
                    isLoading: true,
                    showLocalLoading: false,
                    searchText: "Avengers",
                    loadMore: { _ in }
                )
                .previewDisplayName("Loading")
                SearchResultsRowView(
                    results: [],
                    isLoading: false,
                    showLocalLoading: false,
                    searchText: "Avengers",
                    loadMore: { _ in }
                )
                .previewDisplayName("Empty")
                SearchResultsRowView(
                    results: [sampleItem],
                    isLoading: false,
                    showLocalLoading: false,
                    searchText: "Avengers",
                    loadMore: { _ in }
                )
                .previewDisplayName("Populated")
            }
            .previewLayout(.sizeThatFits)
        }
    }

    struct KeywordSuggestionsRowView_Previews: PreviewProvider {
        static let sampleKeyword = Keyword(id: 1, name: "Action")
        static var previews: some View {
            Group {
                KeywordSuggestionsRowView(keywords: [], isLoading: true, choose: { _ in })
                    .previewDisplayName("Loading")
                KeywordSuggestionsRowView(keywords: [], isLoading: false, choose: { _ in })
                    .previewDisplayName("Empty")
                KeywordSuggestionsRowView(keywords: [sampleKeyword, sampleKeyword], isLoading: false, choose: { _ in })
                    .previewDisplayName("Populated")
            }
            .previewLayout(.sizeThatFits)
        }
    }
#endif
