//  Jonathan Ritchey

import Foundation

public struct MockNetworkService: NetworkServiceProtocol {
    let jsonDecoder: JSONDecoder
    let data: Data
    let duration: Duration
    let clock: any Clock<Duration>
    
    public init(
        data: Data,
        jsonDecoder: JSONDecoder = JSONDecoder(),
        duration: Duration = .zero,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.data = data
        self.jsonDecoder = jsonDecoder
        self.duration = duration
        self.clock = clock
    }
    
    public init(
        responseJSON: String = "",
        jsonDecoder: JSONDecoder = JSONDecoder(),
        duration: Duration = .zero,
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        let data = Data(responseJSON.utf8)
        self.init(
            data: data,
            jsonDecoder: jsonDecoder,
            duration: duration,
            clock: clock
        )
    }

    public func request<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> Model {
        try await sleep()
        return try jsonDecoder.decode(Model.self, from: data)
    }

    public func requestModels<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> [Model] {
        try await sleep()
        return try jsonDecoder.decode([Model].self, from: data)
    }

    public func requestVoid(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> NetworkServiceEmptyResponseResult {
        try await sleep()
        return .success(code: 200)
    }
    
    private func sleep() async throws {
        guard duration > .zero else { return }
        try Task.checkCancellation()
        try await clock.sleep(for: duration)
    }
}
