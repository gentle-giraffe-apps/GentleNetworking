//  Jonathan Ritchey

import Foundation

public struct MockNetworkService: NetworkServiceProtocol {
    let jsonDecoder: JSONDecoder
    let responseData: Data
    let delayInMilliseconds: Int
    
    public init(
        responseJSON: String = "",
        jsonDecoder: JSONDecoder = {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
            return decoder
        }(),
        delayInMilliseconds: Int = 2000
    ) {
        self.responseData = Data(responseJSON.utf8)
        self.jsonDecoder = jsonDecoder
        self.delayInMilliseconds = delayInMilliseconds
    }

    public func request<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> Model {
        try await Task.sleep(for: ContinuousClock.Duration.milliseconds(delayInMilliseconds))
        return try jsonDecoder.decode(Model.self, from: responseData)
    }

    public func requestModels<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> [Model] {
        try await Task.sleep(for: ContinuousClock.Duration.milliseconds(delayInMilliseconds))
        return try jsonDecoder.decode([Model].self, from: responseData)
    }

    public func requestVoid(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> NetworkServiceEmptyResponseResult {
        try await Task.sleep(for: ContinuousClock.Duration.milliseconds(delayInMilliseconds))
        return .success(code: 200)
    }
}
