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
                .font(.system(size: 50))
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
        // Display trending connection error if present
        if let error = vm.connectionError {
            VStack {
                Image(systemName: "antenna.radiowaves.left.and.right.slash").font(.largeTitle)
                    .foregroundColor(.orange) // Changed Icon
                Text("Cannot Load Trending").font(.headline).padding(.bottom, 2) // Changed Text
                Text(error).font(.caption).multilineTextAlignment(.center).padding(.horizontal)
                Button("Retry") { Task { await vm.bootstrap() } }
                    .buttonStyle(.bordered).padding(.top, 5)
            }
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
            .padding()

        } else if vm.items.isEmpty && vm.isLoading {
            // Show shimmer only if items are empty and loading
            Text("Trending").font(.title2).padding(.horizontal).opacity(0) // Placeholder title for spacing
            HorizontalMediaRow(items: [], isLoading: true) { _ in }
                .frame(height: 200) // Consistent height
        } else if !vm.items.isEmpty {
            // Show trending items
            Text("Trending")
                .font(.title2)
                .padding(.horizontal)

            HorizontalMediaRow(
                items: vm.items,
                isLoading: vm.isLoading
            ) { item in
                vm.loadMoreIfNeeded(current: item)
            }
        } else {
            // Empty state for trending (after load, if no items and no error)
            Text("Trending")
                .font(.title2)
                .padding(.horizontal)
            Text("No trending items found.")
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100, alignment: .center) // Smaller height for empty message
        }
    }

    @ViewBuilder
    private var searchResultsSection: some View {
        // Filter out suggestions that are already active keywords
        let filteredSuggestions = overseerrUsersVM.keywordSuggestions
            .filter { !overseerrUsersVM.activeKeywordIDs.contains($0.id) }

        Group {
            // Search Results for Movies/TV
            if (isSearchLoadingLocal || overseerrUsersVM.isLoadingSearch) && overseerrUsersVM.results.isEmpty {
                // Shimmer for search results when loading and no results yet
                Text("Search Results").font(.headline).padding(.horizontal).opacity(0) // Placeholder title for spacing
                HorizontalMediaRow(items: [], isLoading: true) { _ in }
                    .frame(height: 200) // Consistent height
            } else if !isSearchLoadingLocal && !overseerrUsersVM.isLoadingSearch && overseerrUsersVM.results
                .isEmpty && !searchText.isEmpty
            {
                // No results found message only if search wasn't empty and not loading
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
                .frame(height: 160) // Give it some space
                .padding(.horizontal)
            } else if !overseerrUsersVM.results.isEmpty {
                // Display actual search results
                Text("Search Results")
                    .font(.headline)
                    .padding(.horizontal)

                HorizontalMediaRow(
                    items: overseerrUsersVM.results,
                    isLoading: overseerrUsersVM.isLoadingSearch // Pass loading state
                ) { item in
                    overseerrUsersVM.loadMoreIfNeeded(current: item,
                                                      within: overseerrUsersVM.results)
                }
            }

            // Keyword Suggestions (Handles its own loading/empty state)
            if overseerrUsersVM.isLoadingKeywords {
                Text("Search by Keyword").font(.headline).padding(.horizontal).opacity(0) // Placeholder title
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(0 ..< 5, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.3))
                                .frame(width: 100, height: 32).shimmer()
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 40)
            } else if !filteredSuggestions.isEmpty {
                Text("Search by Keyword")
                    .font(.headline)
                    .padding(.horizontal)

                KeywordSuggestionRow(keywords: filteredSuggestions) { kw in
                    // Activating a keyword will clear searchText via overseerrUsersVM.searchQuery's .onChange
                    // and potentially trigger a view switch in OverseerrUsersHomeEntry
                    overseerrUsersVM.activate(keyword: kw)
                    searchFieldFocused = false // Dismiss keyboard
                    UIApplication.shared.endEditing()
                }
            }

            // ** Recommendations Section **
            VStack(alignment: .leading, spacing: 16) { // Group recommendations
                // Movie Recommendations
                if overseerrUsersVM.isLoadingMovieRecs && overseerrUsersVM.movieRecs.isEmpty {
                    Text("Movies You Might Like").font(.headline).padding(.horizontal).opacity(0) // Placeholder title
                    HorizontalMediaRow(items: [], isLoading: true) { _ in }
                        .frame(height: 200)
                } else if !overseerrUsersVM.movieRecs.isEmpty {
                    Text("Movies You Might Like")
                        .font(.headline).padding(.horizontal)
                    HorizontalMediaRow(
                        items: overseerrUsersVM.movieRecs,
                        isLoading: overseerrUsersVM.isLoadingMovieRecs
                    ) { item in
                        overseerrUsersVM.loadMoreMovieRecsIfNeeded(current: item)
                    }
                }

                // TV Recommendations
                if overseerrUsersVM.isLoadingTvRecs && overseerrUsersVM.tvRecs.isEmpty {
                    Text("Shows You Might Like").font(.headline).padding(.horizontal).opacity(0) // Placeholder title
                    HorizontalMediaRow(items: [], isLoading: true) { _ in }
                        .frame(height: 200)
                } else if !overseerrUsersVM.tvRecs.isEmpty {
                    Text("Shows You Might Like")
                        .font(.headline).padding(.horizontal)
                    HorizontalMediaRow(
                        items: overseerrUsersVM.tvRecs,
                        isLoading: overseerrUsersVM.isLoadingTvRecs
                    ) { item in
                        overseerrUsersVM.loadMoreTvRecsIfNeeded(current: item)
                    }
                }
            }
            .padding(.bottom) // Add padding at the end of the scroll content if recs are shown
        }
    }
}
