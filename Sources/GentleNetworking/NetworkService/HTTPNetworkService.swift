//  Jonathan Ritchey
import Foundation

public struct HTTPNetworkService: NetworkServiceProtocol {
    let transport: HTTPTransportProtocol
    let authService: AuthServiceProtocol
    let invalidationHandler: TokenInvalidationHandler?
    let jsonDecoder: JSONDecoder
    let jsonEncoder: JSONEncoder
    
    public init(
        transport: HTTPTransportProtocol = RetryTransport(),
        authService: AuthServiceProtocol = SystemKeyChainAuthService(),
        invalidationHandler: TokenInvalidationHandler? = nil,
        jsonDecoder: JSONDecoder? = nil,
        jsonEncoder: JSONEncoder? = nil
    ) {
        self.transport = transport
        self.authService = authService
        self.invalidationHandler = invalidationHandler
        self.jsonDecoder = jsonDecoder ?? JSONDecoder()
        self.jsonEncoder = jsonEncoder ?? JSONEncoder()
    }
    
    public func request<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> Model {
        let (data, _) = try await getData(from: endpoint, via: environment)
        return try jsonDecoder.decode(Model.self, from: data)
    }
    
    public func requestModels<Model: Decodable>(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> [Model] {
        let (data, _) = try await getData(from: endpoint, via: environment)
        return try jsonDecoder.decode([Model].self, from: data)
    }
    
    public func requestVoid(
        to endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> NetworkServiceEmptyResponseResult {
        let (_, response) = try await getData(from: endpoint, via: environment)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 500
            let statusError = HTTPStatusError(statusCode: code) ?? .serverError(code)
            throw NetworkError.httpStatusError(statusError)
        }
        return .success(code: http.statusCode)
    }
    
    private func getData(
        from endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> (Data, URLResponse) {
        var request = try endpoint.from(environment.baseURL, jsonEncoder: jsonEncoder)
        if endpoint.requiresAuth {
            request = try await authService.authorize(request)
        }
        let (data, response) = try await transport.data(for: request)
        // ✅ DEBUG: print raw text if possible
        print("➡️ \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        if let text = String(data: data, encoding: .utf8) {
            print("🔍 Response Text:\n\(text)")
        } else {
            print("🔍 Response Data (non-UTF8, \(data.count) bytes)")
        }
        guard (200..<300).contains(response.statusCode) else {
            let statusError = HTTPStatusError(statusCode: response.statusCode) ?? .serverError(response.statusCode)
            if case .unauthorized = statusError {
                await invalidationHandler?.handleInvalidToken()
            }
            throw NetworkError.httpStatusError(statusError)
        }
        return (data, response)
    }
}
