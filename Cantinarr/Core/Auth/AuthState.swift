import Foundation
import SwiftUI

/// Single source of truth for Overseerr session state.
enum AuthState: Equatable {
    case unknown // still probing
    case authenticated(expiry: Date?) // expiry lets us pre‑empt logout
    case unauthenticated
}
