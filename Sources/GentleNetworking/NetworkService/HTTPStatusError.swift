//  Jonathan Ritchey
import Foundation

public enum HTTPStatusError: Error, Sendable, Equatable {
    // Named client errors
    case unauthorized          // 401
    case forbidden             // 403
    case notFound              // 404
    case rateLimited           // 429

    // Named server errors
    case internalServerError   // 500
    case serviceUnavailable    // 503

    // Catch-all categories
    case clientError(Int)      // 400-499 not named above
    case serverError(Int)      // 500-599 not named above
    case redirect(Int)         // 300-399

    /// Creates an HTTPStatusError from an HTTP status code.
    /// Returns nil for codes in the 200-299 success range.
    public init?(statusCode: Int) {
        switch statusCode {
        case 200..<300: return nil
        case 300..<400: self = .redirect(statusCode)
        case 401:       self = .unauthorized
        case 403:       self = .forbidden
        case 404:       self = .notFound
        case 429:       self = .rateLimited
        case 400..<500: self = .clientError(statusCode)
        case 500:       self = .internalServerError
        case 503:       self = .serviceUnavailable
        case 500..<600: self = .serverError(statusCode)
        default:        self = .serverError(statusCode)
        }
    }

    public var statusCode: Int {
        switch self {
        case .unauthorized:        return 401
        case .forbidden:           return 403
        case .notFound:            return 404
        case .rateLimited:         return 429
        case .internalServerError: return 500
        case .serviceUnavailable:  return 503
        case .clientError(let code),
             .serverError(let code),
             .redirect(let code):  return code
        }
    }
}
