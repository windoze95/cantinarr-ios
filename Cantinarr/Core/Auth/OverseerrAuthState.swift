// File: OverseerrAuthState.swift
// Purpose: Defines OverseerrAuthState component for Cantinarr

import Foundation
import SwiftUI

/// Single source of truth for Overseerr session state.
enum OverseerrAuthState: Equatable {
    case unknown // still probing
    case authenticated(expiry: Date?) // expiry lets us pre‑empt logout
    case unauthenticated
}
