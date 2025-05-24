// File: OverseerrPlexSSODelegate.swift
// Purpose: Defines OverseerrPlexSSODelegate component for Cantinarr

@MainActor
/// Delegate for receiving the Plex SSO token after the authentication flow completes.
protocol OverseerrPlexSSODelegate: AnyObject {
    func didReceivePlexToken(_ token: String)
}
