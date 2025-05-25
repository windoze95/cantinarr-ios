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
                    // Movies / TV picker
                    Picker("Media", selection: $vm.filters.selectedMedia) {
                        ForEach(MediaType.allCases
                            .filter { $0 != .unknown && $0 != .person && $0 != .collection })
                        { mt in
                            // Filtered for relevant types
                            Text(mt.displayName).tag(mt)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Active keyword pillszzz
                    if !vm.filters.activeKeywordIDs.isEmpty {
                        ActiveKeywordsView()
                            .environmentObject(vm)
                            .padding(.top, 4)
                    }

                    // Results grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)]) {
                        ForEach(vm.results) { item in
                            MediaCardView(id: item.id,
                                          mediaType: item.mediaType,
                                          title: item.title,
                                          posterPath: item.posterPath)
                                .onAppear {
                                    vm.loadMoreIfNeeded(current: item, within: vm.results)
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom) // keeps last row from sitting against the screen edge
                } else { // Search query is not empty
                    Text("Search Results")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        // 1️⃣ While local OR real loading and no results → shimmer
                        if (isSearchLoadingLocal || vm.isLoadingSearch)
                            && vm.results.isEmpty
                        {
                            HorizontalMediaRow(items: [], isLoading: true) { _ in }
                                .frame(height: 180)

                            // 2️⃣ When fully done loading and still no results → “no results”
                        } else if !isSearchLoadingLocal
                            && !vm.isLoadingSearch
                            && vm.results.isEmpty
                        {
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

                            // 3️⃣ Otherwise → show the real results row
                        } else {
                            HorizontalMediaRow(
                                items: vm.results,
                                isLoading: vm.isLoadingSearch
                            ) { item in
                                vm.loadMoreIfNeeded(current: item, within: vm.results)
                            }
                        }
                    }
                    // Only suggestions not already active
                    let filteredSuggestions = vm.keywordSuggestions
                        .filter { !vm.filters.activeKeywordIDs.contains($0.id) }

                    if vm.isLoadingKeywords || !filteredSuggestions.isEmpty {
                        Text("Search by Keyword")
                            .font(.headline)
                            .padding(.horizontal)

                        if vm.isLoadingKeywords {
                            // shimmer placeholders while loading
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(0 ..< 5, id: \.self) { _ in
                                        // pill placeholder
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 100, height: 32)
                                            .shimmer()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else if !filteredSuggestions.isEmpty {
                            KeywordSuggestionRow(keywords: filteredSuggestions) { kw in
                                // Clear the UI search field and dismiss keyboard
                                searchText = ""
                                searchFieldFocused = false

                                vm
                                    .activate(keyword: kw) // This will also trigger view switch if conditions met in
                                // HomeEntry
                            }
                        }
                    }

                    // Movie recommendations
                    if !vm.movieRecs.isEmpty {
                        Text("Movies you might like")
                            .font(.headline).padding(.horizontal)
                        HorizontalMediaRow(
                            items: vm.movieRecs,
                            isLoading: vm.isLoadingMovieRecs
                        ) { item in
                            vm.loadMoreMovieRecsIfNeeded(current: item)
                        }
                    }

                    // TV recommendations
                    if !vm.tvRecs.isEmpty {
                        Text("Shows you might like")
                            .font(.headline).padding(.horizontal)
                        HorizontalMediaRow(
                            items: vm.tvRecs,
                            isLoading: vm.isLoadingTvRecs
                        ) { item in
                            vm.loadMoreTvRecsIfNeeded(current: item)
                        }
                        .padding(.bottom) // keeps last row from sitting against the screen edge
                    }
                }
            }
            .padding(.top, 8) // space below the pinned search bar
        }
        .scrollDismissesKeyboard(.immediately) // hides as soon as you drag
        .simultaneousGesture( // hides on any tap *without*
            TapGesture() // stealing the tap from cells
                .onEnded {
                    searchFieldFocused = false
                    UIApplication.shared.endEditing() // force-hide keyboard
                }
        )
        // any tap on the content area will clear focus
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    searchFieldFocused = false
                    UIApplication.shared.endEditing() // force-hide keyboard
                }
        )

        // 🔒 Sticky search bar
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                SearchBarView(text: $searchText, focus: $searchFieldFocused)
                    .onChange(of: searchText) { _, newValue in
                        if !newValue.isEmpty {
                            // 1) clear out stale cards immediately
                            vm.clearSearchResultsAndRecs()
                            // 2) show shimmer immediately
                            isSearchLoadingLocal = true
                        }
                        vm.searchQuery = newValue // This will be observed by OverseerrUsersHomeEntry
                    }
                    .onChange(of: vm.isLoadingSearch) { loading in
                        // when real search finishes, stop local shimmer
                        if !loading {
                            isSearchLoadingLocal = false
                        }
                    }
            }
            .padding()
            .background(.ultraThinMaterial) // .regularMaterial or .ultraThinMaterial
        }
        .navigationBarTitleDisplayMode(.inline) // compact nav bar, no big title
        .navigationBarBackButtonHidden(true) // Important: hide default back button
    }
}

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
