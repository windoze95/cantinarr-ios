import Foundation

/// Generic error type for API services.
enum APIServiceError: Error, LocalizedError {
    case unauthorized
    case apiError(message: String, statusCode: Int)
    case invalidResponse
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
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
