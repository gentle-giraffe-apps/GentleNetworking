//  Jonathan Ritchey
import Foundation

public enum HTTPMethod: String, Sendable {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case delete  = "DELETE"
    case patch   = "PATCH"
}

public struct EndpointAnyEncodable: Encodable, Sendable {
    private let encode: @Sendable (Encoder) throws -> Void
    public init<T: Encodable & Sendable>(_ value: T) {
        self.encode = value.encode
    }
    public func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}

public protocol EndpointProtocol: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem]? { get }
    var body: [String: EndpointAnyEncodable]? { get }
    var requiresAuth: Bool { get }
}

public extension EndpointProtocol {
    func from(_ baseURL: URL) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)

        if let query, !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query
            url = components?.url ?? url
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let body {
            let encoder = JSONEncoder()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                print("\(error)")
                print("stop")
                throw error
            }
        }
        return request
    }
}

public struct Endpoint: EndpointProtocol {
    public let path: String
    public let method: HTTPMethod
    public var query: [URLQueryItem]?
    public var body: [String: EndpointAnyEncodable]?
    public var requiresAuth: Bool
    public init(path: String, method: HTTPMethod, query: [URLQueryItem]? = nil, body: [String: EndpointAnyEncodable]? = nil, requiresAuth: Bool = false) {
        self.path = path
        self.method = method
        self.query = query
        self.body = body
        self.requiresAuth = requiresAuth
    }
}
