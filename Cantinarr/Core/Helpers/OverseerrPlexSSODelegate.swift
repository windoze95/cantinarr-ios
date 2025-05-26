// File: OverseerrPlexSSODelegate.swift
// Purpose: Defines OverseerrPlexSSODelegate component for Cantinarr

/// Delegate for receiving the Plex SSO token after the authentication flow completes.
@MainActor
protocol OverseerrPlexSSODelegate: AnyObject {
    func didReceivePlexToken(_ token: String)
}
