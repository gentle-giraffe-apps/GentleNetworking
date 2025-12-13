//  Jonathan Ritchey
import Foundation

public struct MatchingTransport: HTTPTransportProtocol {
    public enum MatchingTransportError: Error {
        case notMatched
    }
    public let pattern: RequestPattern
    public let transport: any HTTPTransportProtocol

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard pattern.matches(request) else { throw MatchingTransportError.notMatched }
        return try await transport.data(for: request)
    }
}
