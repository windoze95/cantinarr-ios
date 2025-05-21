// File: PlexSSODelegate.swift
// Purpose: Defines PlexSSODelegate component for Cantinarr

@MainActor
/// Delegate for receiving the Plex SSO token after the authentication flow completes.
protocol PlexSSODelegate: AnyObject {
    func didReceivePlexToken(_ token: String)
}
