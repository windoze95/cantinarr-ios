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
        OverseerrSearchBarResultsView(
            hasActiveKeywords: !vm.filters.activeKeywordIDs.isEmpty,
            vm: vm,
            keywordList: {
                let filtered = vm.keywordSuggestions.filter { !vm.filters.activeKeywordIDs.contains($0.id) }
                OverseerrKeywordFilterListView(
                    keywords: filtered,
                    isLoading: vm.isLoadingKeywords,
                    searchText: $searchText,
                    searchFieldFocused: $searchFieldFocused
                ) { kw in
                    searchText = ""
                    searchFieldFocused = false
                    vm.activate(keyword: kw)
                }
            },
            recRows: {
                OverseerrRecommendationRowsView(
                    movieRecs: vm.movieRecs,
                    tvRecs: vm.tvRecs,
                    isLoadingMovieRecs: vm.isLoadingMovieRecs,
                    isLoadingTvRecs: vm.isLoadingTvRecs,
                    loadMoreMovie: { vm.loadMoreMovieRecsIfNeeded(current: $0) },
                    loadMoreTv: { vm.loadMoreTvRecsIfNeeded(current: $0) }
                )
            },
            searchText: $searchText,
            searchQuery: vm.searchQuery,
            selectedMedia: $vm.filters.selectedMedia,
            results: vm.results,
            isLoadingSearch: vm.isLoadingSearch,
            isSearchLoadingLocal: $isSearchLoadingLocal,
            loadMore: { vm.loadMoreIfNeeded(current: $0, within: vm.results) },
            searchFieldFocused: _searchFieldFocused,
            onSearchQueryChange: { newValue in
                if !newValue.isEmpty {
                    vm.clearSearchResultsAndRecs()
                    isSearchLoadingLocal = true
                }
                vm.searchQuery = newValue
            }
        )
        .onChange(of: vm.isLoadingSearch) { loading in
            if !loading {
                isSearchLoadingLocal = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
}
