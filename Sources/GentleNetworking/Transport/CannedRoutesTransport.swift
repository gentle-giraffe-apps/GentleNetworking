//  Jonathan Ritchey
import Foundation

public struct CannedRoute: Sendable {
    public let pattern: RequestPattern
    public let response: CannedResponse
}

public struct CannedRoutesTransport: HTTPTransportProtocol {

    public enum Mode: Sendable {
        /// First matching route wins (routes are evaluated in order).
        case firstMatchWins
        /// Require exactly one match; 0 or >1 matches throws.
        case requireUniqueMatch
    }

    public enum Error: Swift.Error, Sendable {
        case missingRequestURL
        case noMatch
        case ambiguousMatch(count: Int)
    }

    public let routes: [CannedRoute]
    public let mode: Mode

    public init(routes: [CannedRoute], mode: Mode = .firstMatchWins) {
        self.routes = routes
        self.mode = mode
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard request.url != nil else { throw Error.missingRequestURL }

        let matches = routes.filter { $0.pattern.matches(request) }

        switch mode {
        case .firstMatchWins:
            guard let route = matches.first else { throw Error.noMatch }
            return try makeTuple(for: route, request: request)

        case .requireUniqueMatch:
            guard !matches.isEmpty else { throw Error.noMatch }
            guard matches.count == 1 else { throw Error.ambiguousMatch(count: matches.count) }
            return try makeTuple(for: matches[0], request: request)
        }
    }

    private func makeTuple(for route: CannedRoute, request: URLRequest) throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw Error.missingRequestURL }
        let response = try route.response.makeResponse(url: url)
        return (route.response.data, response)
    }
}
