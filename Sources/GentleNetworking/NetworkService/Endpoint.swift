//  Jonathan Ritchey
import Foundation

public enum HTTPMethod: String, Sendable {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case delete  = "DELETE"
    case patch   = "PATCH"
}

public protocol EndpointProtocol {
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem]? { get }
    var body: [String: Any]? { get }
    var requiresAuth: Bool { get }
}

public extension EndpointProtocol {
    func from(_ baseURL: URL) -> URLRequest {
        var url = baseURL.appendingPathComponent(path)

        if let query, !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            url = components?.url ?? url
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}

public struct Endpoint: EndpointProtocol {
    public let path: String
    public let method: HTTPMethod
    public var query: [URLQueryItem]?
    public var body: [String: Any]?
    public var requiresAuth: Bool
    public init(path: String, method: HTTPMethod, query: [URLQueryItem]? = nil, body: [String : Any]? = nil, requiresAuth: Bool = false) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.requiresAuth = requiresAuth
    }
}
