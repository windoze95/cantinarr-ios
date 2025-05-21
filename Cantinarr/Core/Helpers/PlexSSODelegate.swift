// File: PlexSSODelegate.swift
// Purpose: Defines PlexSSODelegate component for Cantinarr

@MainActor
protocol PlexSSODelegate: AnyObject {
    func didReceivePlexToken(_ token: String)
}
