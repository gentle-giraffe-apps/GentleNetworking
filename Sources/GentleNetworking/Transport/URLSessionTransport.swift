//  Jonathan Ritchey
import Foundation

public struct URLSessionTransport: HTTPTransportProtocol {
    let session: URLSession
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponseType
        }
        return (data, response)
    }
}
