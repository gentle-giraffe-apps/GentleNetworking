//  Jonathan Ritchey
import Foundation

public protocol APIEnvironmentProtocol: Sendable {
    var _baseURL: URL? { get }
}

public extension APIEnvironmentProtocol {
    var baseURL: URL {
        guard let url = _baseURL else { fatalError("Missing or invalid base URL") }
        return url
    }
}
