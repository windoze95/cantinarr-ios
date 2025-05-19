import Foundation

enum UserRole {
    case admin, user, guest
}

class UserSession: ObservableObject {
    // Default role; in a real app, this may be set upon user login
    @Published var role: UserRole = .user
}
