//  Jonathan Ritchey
import Foundation

public protocol HTTPTransportProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
