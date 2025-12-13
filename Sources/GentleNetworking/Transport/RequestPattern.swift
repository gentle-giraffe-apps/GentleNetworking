//  Jonathan Ritchey
import Foundation

public struct RequestPattern: Sendable, Hashable {
    public let method: HTTPMethod?
    public let hostRegex: String?
    public let pathRegex: String

    public init(
        method: HTTPMethod? = nil,
        hostRegex: String? = nil,
        pathRegex: String
    ) {
        self.method = method
        self.hostRegex = hostRegex
        self.pathRegex = pathRegex
    }

    public init(
        method: HTTPMethod? = nil,
        host: String? = nil,
        path: String
    ) {
        self.init(
            method: method,
            hostRegex: host.map(NSRegularExpression.escapedPattern(for:)),
            pathRegex: "^\(NSRegularExpression.escapedPattern(for: path))$"
        )
    }

    public func matches(_ request: URLRequest) -> Bool {
        if let method, request.httpMethod?.uppercased() != method.rawValue { return false }

        guard let url = request.url else { return false }

        if let hostRegex {
            let host = url.host ?? ""
            guard host.range(of: hostRegex, options: .regularExpression) != nil else { return false }
        }

        let path = url.path
        guard path.range(of: pathRegex, options: .regularExpression) != nil else { return false }

        return true
    }
}
