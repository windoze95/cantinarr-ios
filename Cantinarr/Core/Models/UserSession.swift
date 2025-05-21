import Foundation

/// Authorization level of the current user.
enum UserRole {
    case admin, user, guest
}

/// Observable store describing the logged‑in user's role.
class UserSession: ObservableObject {
    // Default role; in a real app, this may be set upon user login
    @Published var role: UserRole = .user
}
