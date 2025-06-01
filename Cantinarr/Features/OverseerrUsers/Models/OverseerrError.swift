import Foundation

/// Errors specific to Overseerr API interactions.
enum OverseerrError: Error, LocalizedError {
    case notAuthenticated
    case apiError(message: String, statusCode: Int)
    case invalidResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Authentication required."
        case let .apiError(message, _):
            return message
        case .invalidResponse:
            return "Invalid response from server."
        case let .network(error):
            return error.localizedDescription
        }
    }
}
