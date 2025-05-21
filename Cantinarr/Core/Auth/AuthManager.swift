// File: AuthManager.swift
// Purpose: Defines AuthManager component for Cantinarr

import Combine
import Foundation

/// Actor = thread‑safe without extra locks.
actor AuthManager {
    // MARK: – Public singleton

    static let shared = AuthManager()
    private init() {}

    // MARK: – Published state

    nonisolated let subject = CurrentValueSubject<AuthState, Never>(.unknown)
    nonisolated var publisher: AnyPublisher<AuthState, Never> {
        subject.eraseToAnyPublisher()
    }

    nonisolated var value: AuthState { subject.value }

    // MARK: – Config injected once at app launch

    private var service: OverseerrAPIService!

    /// Call once from `App.bootstrap` after you know which Overseerr you're talking to.
    func configure(service: OverseerrAPIService) {
        self.service = service
        lastProbe = nil
        Task { await probeSession() }
    }

    // MARK: – Cached validation

    private var lastProbe: Date?

    /// Cheap helper any view‑model can call.
    func ensureAuthenticated() async {
        // 1. Fast path — already good?
        if case .authenticated = subject.value { return }

        // 2. Throttle: don’t probe more than once every 30 s
        if let last = lastProbe, Date().timeIntervalSince(last) < 30 { return }

        lastProbe = Date()
        await probeSession()
    }

    /// Explicit (re)validation – used on app launch & when a request 401s.
    func probeSession() async {
        guard let s = service else { return }

        // optimistic: if Cookie exists we *tentatively* say we're auth’d
        if HTTPCookieStorage.shared.cookies?
            .contains(where: { $0.name == "connect.sid" }) == true
        {
            subject.send(.authenticated(expiry: nil))
        }

        // Slow network probe (runs once / 30 s at most)
        let ok = await s.isAuthenticated()
        await MainActor.run {
            subject.send(ok ? .authenticated(expiry: nil) : .unauthenticated)
        }
    }

    /// Use when an endpoint returns 401/403.
    func recoverFromAuthFailure() async {
        // avoid infinite loops
        if case .unknown = subject.value { return }
        subject.send(.unknown)
        await probeSession()
    }
}
