//  Jonathan Ritchey
import Foundation

public struct HTTPNetworkService: NetworkServiceProtocol {
    let transport: HTTPTransportProtocol
    let authService: AuthServiceProtocol
    let invalidationHandler: TokenInvalidationHandler?
    let jsonDecoder: JSONDecoder
    
    public init(
        transport: HTTPTransportProtocol = URLSessionTransport(session: .shared),
        authService: AuthServiceProtocol = SystemKeyChainAuthService(),
        invalidationHandler: TokenInvalidationHandler? = nil,
        jsonDecoder: JSONDecoder? = nil
    ) {
        self.transport = transport
        self.authService = authService
        self.invalidationHandler = invalidationHandler
        self.jsonDecoder = jsonDecoder ?? Self.makeDefaultDecoder()
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
            throw NetworkError.invalidStatusCode((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        return .success(code: http.statusCode)
    }
    
    private func getData(
        from endpoint: EndpointProtocol,
        via environment: APIEnvironmentProtocol
    ) async throws -> (Data, URLResponse) {
        var request = endpoint.from(environment.baseURL)
        if endpoint.requiresAuth {
            request = try authService.authorize(request)
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
            if response.statusCode == 401 {
                await invalidationHandler?.handleInvalidToken()
            }
            throw NetworkError.invalidStatusCode(response.statusCode)
        }
        return (data, response)
    }
    
    private static func makeDefaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        return decoder
    }
}
