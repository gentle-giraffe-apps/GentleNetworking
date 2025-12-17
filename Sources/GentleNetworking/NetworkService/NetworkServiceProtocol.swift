//  Jonathan Ritchey

import Foundation
import Security

public enum NetworkServiceEmptyResponseResult {
    case success(code: Int)
}

public protocol NetworkServiceProtocol: Sendable {
    func request<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> Model
    func requestModels<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> [Model]
    func requestVoid(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> NetworkServiceEmptyResponseResult
}
