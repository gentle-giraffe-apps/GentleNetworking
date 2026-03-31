# API Reference

## Protocols

### NetworkServiceProtocol
```swift
public protocol NetworkServiceProtocol: Sendable {
    func request<Model: Decodable>(to endpoint: EndpointProtocol, via environment: APIEnvironmentProtocol) async throws -> Model
    func requestModels<Model: Decodable>(to endpoint: EndpointProtocol, via environment: APIEnvironmentProtocol) async throws -> [Model]
    func requestVoid(to endpoint: EndpointProtocol, via environment: APIEnvironmentProtocol) async throws -> NetworkServiceEmptyResponseResult
}
```
Core networking interface — decode a single model, an array, or expect no body.

### HTTPTransportProtocol
```swift
public protocol HTTPTransportProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Abstraction over URLSession. Swap implementations for testing.

### EndpointProtocol
```swift
public protocol EndpointProtocol: Sendable {
    var path: String { get }
    var method: HTTPMethod { get }
    var query: [URLQueryItem]? { get }
    var body: [String: EndpointAnyEncodable]? { get }
    var requiresAuth: Bool { get }
}
```
Describes an API endpoint. Implement as an enum for type-safe routing.

**Extension method:**
```swift
func from(_ baseURL: URL, jsonEncoder: JSONEncoder = JSONEncoder()) throws -> URLRequest
```
Builds a `URLRequest` from the endpoint and a base URL.

### APIEnvironmentProtocol
```swift
public protocol APIEnvironmentProtocol: Sendable {
    var _baseURL: URL? { get }
}
```
Provides the base URL. Computed `baseURL` property fatal-errors if nil.

### AuthServiceProtocol
```swift
public protocol AuthServiceProtocol: Sendable {
    var headerField: String { get }          // default: "Authorization"
    var headerValuePrefix: String { get }    // default: "Bearer "
    var keyChainKey: String { get }          // default: "accessToken"
    var keyChainStore: KeyChainStoreProtocol { get }
    func loadAccessToken() async throws -> String?
    func saveAccessToken(_ token: String) async throws
    func authorize(_ request: URLRequest) async throws -> URLRequest
    func deleteAccessToken() async throws
}
```
Token lifecycle management. All methods have default implementations via protocol extension.

### KeyChainStoreProtocol
```swift
public protocol KeyChainStoreProtocol: Sendable {
    func save(_ value: String, forKey key: String) async throws
    func value(forKey key: String) async throws -> String?
    func deleteValue(forKey key: String) async throws
}
```
Key-value persistence abstraction over the system keychain.

### TokenInvalidationHandler
```swift
public protocol TokenInvalidationHandler: Sendable {
    func handleInvalidToken() async
}
```
Called by `HTTPNetworkService` on HTTP 401 before throwing.

### ServerTrustEvaluator
```swift
public protocol ServerTrustEvaluator: Sendable {
    func evaluate(_ trust: SecTrust, forHost host: String) throws
}
```
SSL pinning evaluation strategy. Implement to define custom trust validation. Throw `ServerTrustError` on failure.

---

## Concrete Types

### HTTPNetworkService : NetworkServiceProtocol
```swift
public struct HTTPNetworkService: NetworkServiceProtocol {
    public init(
        transport: HTTPTransportProtocol = URLSessionTransport(session: .shared),
        authService: AuthServiceProtocol = SystemKeyChainAuthService(),
        invalidationHandler: TokenInvalidationHandler? = nil,
        jsonDecoder: JSONDecoder? = nil,
        jsonEncoder: JSONEncoder? = nil
    )
}
```
Production network service. Encodes endpoints, authorizes requests, validates 200-299 status codes, handles 401 token invalidation, decodes responses.

### URLSessionTransport : HTTPTransportProtocol
```swift
public struct URLSessionTransport: HTTPTransportProtocol {
    public init(session: URLSession = .shared)
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Wraps `URLSession.data(for:)` and casts to `HTTPURLResponse`.

### CannedResponseTransport : HTTPTransportProtocol
```swift
public struct CannedResponseTransport: HTTPTransportProtocol {
    public init(cannedResponse: CannedResponse)
    public init(string: String, encoding: String.Encoding = .utf8, statusCode: Int = 200, headerFields: [String: String]? = nil)
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Returns a single fixed response for any request. Useful for simple test stubs.

### CannedRoutesTransport : HTTPTransportProtocol
```swift
public struct CannedRoutesTransport: HTTPTransportProtocol {
    public init(routes: [CannedRoute], mode: Mode = .firstMatchWins)
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Routes requests to different canned responses based on `RequestPattern` matching.

### MatchingTransport : HTTPTransportProtocol
```swift
public struct MatchingTransport: HTTPTransportProtocol {
    public let pattern: RequestPattern
    public let transport: any HTTPTransportProtocol
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Wraps another transport; only forwards requests that match the pattern. Throws `MatchingTransportError.notMatched` otherwise.

### PinningTransport : HTTPTransportProtocol
```swift
public struct PinningTransport: HTTPTransportProtocol {
    public init(
        pinnedDomains: [String: any ServerTrustEvaluator],
        configuration: URLSessionConfiguration = .default
    )
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
SSL pinning transport. Creates an internal `URLSession` with a delegate that routes TLS challenges through per-domain `ServerTrustEvaluator` instances. Unpinned domains use default trust evaluation.

### PublicKeyPinningEvaluator : ServerTrustEvaluator
```swift
public struct PublicKeyPinningEvaluator: ServerTrustEvaluator {
    public let pinnedKeyHashes: Set<Data>
    public init(pinnedKeyHashes: Set<Data>)
    public func evaluate(_ trust: SecTrust, forHost host: String) throws
}
```
Pins SHA-256 hashes of server public keys. Extracts keys from the certificate chain via `SecCertificateCopyKey` + `SecKeyCopyExternalRepresentation`, hashes with CryptoKit SHA-256, and compares against the pinned set. Recommended over certificate pinning — survives cert renewals.

### CertificatePinningEvaluator : ServerTrustEvaluator
```swift
public struct CertificatePinningEvaluator: ServerTrustEvaluator {
    public let pinnedCertificates: Set<Data>
    public init(pinnedCertificates: Set<Data>)
    public func evaluate(_ trust: SecTrust, forHost host: String) throws
}
```
Pins DER-encoded certificate bytes. Compares certificates in the chain via `SecCertificateCopyData` against the pinned set. Simpler but breaks on every certificate renewal.

### ETagTransport : HTTPTransportProtocol
```swift
public struct ETagTransport: HTTPTransportProtocol {
    public init(
        inner: HTTPTransportProtocol = URLSessionTransport(session: .shared),
        store: ETagStoreProtocol = InMemoryETagStore()
    )
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Conditional GET transport. Caches ETag values from successful GET responses and sends `If-None-Match` on subsequent requests. On HTTP 304, returns the cached response body. Non-GET requests pass through unchanged.

### ETagStoreProtocol
```swift
public protocol ETagStoreProtocol: Sendable {
    func cachedResponse(for key: String) async -> ETagCacheEntry?
    func store(_ entry: ETagCacheEntry, for key: String) async
    func remove(for key: String) async
    func removeAll() async
}
```
Cache storage abstraction for ETag entries. Implement for custom persistence (disk, database).

### ETagCacheEntry
```swift
public struct ETagCacheEntry: Sendable {
    public let etag: String
    public let data: Data
    public let response: HTTPURLResponse
    public init(etag: String, data: Data, response: HTTPURLResponse)
}
```
Cached response data paired with its ETag value.

### InMemoryETagStore : ETagStoreProtocol
```swift
public actor InMemoryETagStore: ETagStoreProtocol {
    public init(maxEntries: Int = 100)
}
```
Actor-isolated in-memory LRU cache. Evicts least-recently-used entries when `maxEntries` is exceeded.

### ReauthTransport : HTTPTransportProtocol
```swift
public struct ReauthTransport: HTTPTransportProtocol {
    public init(
        inner: HTTPTransportProtocol = RetryTransport(),
        authService: AuthServiceProtocol = SystemKeyChainAuthService(),
        refreshToken: @escaping @Sendable () async throws -> Void
    )
    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
```
Intercepts HTTP 401 responses, calls the `refreshToken` closure, re-authorizes the original request via `authService`, and retries once. Concurrent 401s are serialized — only one refresh executes at a time.

### Endpoint : EndpointProtocol
```swift
public struct Endpoint: EndpointProtocol {
    public init(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem]? = nil,
        body: [String: EndpointAnyEncodable]? = nil,
        requiresAuth: Bool = false
    )
}
```
Value type for ad-hoc endpoint definitions. For type-safe APIs, prefer a custom enum conforming to `EndpointProtocol`.

### DefaultAPIEnvironment : APIEnvironmentProtocol, Equatable
```swift
public struct DefaultAPIEnvironment: APIEnvironmentProtocol, Equatable {
    public let _baseURL: URL?
    public init(baseURL: URL? = nil)
}
```
Simple base URL holder.

### SystemKeyChainAuthService : AuthServiceProtocol
```swift
public struct SystemKeyChainAuthService: AuthServiceProtocol {
    public let keyChainStore: any KeyChainStoreProtocol & Sendable
    public init()
}
```
Uses `SystemKeyChainStore` for token persistence.

### SystemKeyChainStore : KeyChainStoreProtocol
```swift
public final class SystemKeyChainStore: KeyChainStoreProtocol {
    public init(service: String = Bundle.main.bundleIdentifier ?? "com.example.app")
    public func save(_ value: String, forKey key: String) async throws
    public func value(forKey key: String) async throws -> String?
    public func deleteValue(forKey key: String) async throws
}
```
System keychain wrapper using Security framework. The only class in the library (required by keychain API lifecycle).

### MockNetworkService : NetworkServiceProtocol
```swift
public struct MockNetworkService: NetworkServiceProtocol {
    public init(data: Data, jsonDecoder: JSONDecoder = JSONDecoder(), duration: Duration = .zero, clock: any Clock<Duration> = ContinuousClock())
    public init(responseJSON: String = "", jsonDecoder: JSONDecoder = JSONDecoder(), duration: Duration = .zero, clock: any Clock<Duration> = ContinuousClock())
}
```
Returns pre-loaded JSON. Supports simulated latency via `duration`.

### MockKeyChainStore : KeyChainStoreProtocol
```swift
public actor MockKeyChainStore: KeyChainStoreProtocol {
    public func save(_ value: String, forKey key: String) async throws
    public func value(forKey key: String) async throws -> String?
    public func deleteValue(forKey key: String) async throws
}
```
In-memory `[String: String]` dictionary. Actor-isolated for thread safety.

### RequestPattern : Sendable, Hashable
```swift
public struct RequestPattern: Sendable, Hashable {
    public init(method: HTTPMethod? = nil, hostRegex: String? = nil, pathRegex: String)
    public init(method: HTTPMethod? = nil, host: String? = nil, path: String)  // escapes special chars
    public func matches(_ request: URLRequest) -> Bool
}
```
Regex-based request matching. Nil `method`/`hostRegex` matches any. Literal initializer auto-escapes.

### CannedResponse : Sendable
```swift
public struct CannedResponse: Sendable {
    public init(data: Data, statusCode: Int = 200, httpVersion: String? = "HTTP/1.1", headerFields: [String: String]? = nil)
    public init(string: String, encoding: String.Encoding = .utf8, statusCode: Int = 200, httpVersion: String? = "HTTP/1.1", headerFields: [String: String]? = nil)
    public func makeResponse(url: URL) throws -> HTTPURLResponse
}
```
Value type holding response data, status code, and headers.

### CannedRoute : Sendable
```swift
public struct CannedRoute: Sendable {
    public let pattern: RequestPattern
    public let response: CannedResponse
}
```
Pairs a `RequestPattern` with a `CannedResponse` for use in `CannedRoutesTransport`.

---

## Enums

### HTTPMethod : String, Sendable
```swift
case get = "GET", post = "POST", put = "PUT", delete = "DELETE", patch = "PATCH"
```

### NetworkError : Error, Sendable
```swift
case invalidResponseType
case httpStatusError(HTTPStatusError)
```

### HTTPStatusError : Error, Sendable, Equatable
```swift
case unauthorized          // 401
case forbidden             // 403
case notFound              // 404
case rateLimited           // 429
case internalServerError   // 500
case serviceUnavailable    // 503
case clientError(Int)      // 400-499 not named above
case serverError(Int)      // 500-599 not named above
case redirect(Int)         // 300-399
```

Factory initializer and status code accessor:
```swift
/// Returns nil for 200-299 success codes
public init?(statusCode: Int)

/// The raw HTTP status code for any case
public var statusCode: Int { get }
```

### ServerTrustError : Error, Sendable
```swift
case trustEvaluationFailed
case noCertificateFound
case noPublicKeyFound
case certificatePinningFailed(host: String)
```

### NetworkServiceEmptyResponseResult
```swift
case success(code: Int)
```

### KeyChainStoreError : Error
```swift
case stringEncodingFailed
case stringDecodingFailed
case unexpectedStatus(OSStatus)
```

### CannedRoutesTransport.Mode : Sendable
```swift
case firstMatchWins       // First matching route wins (evaluated in order)
case requireUniqueMatch   // 0 or >1 matches throws
```

### Nested Error Enums

| Owner | Cases |
|-------|-------|
| `CannedResponse.Error` | `failedToCreateHTTPURLResponse` |
| `CannedResponseTransport.Error` | `missingRequestURL` |
| `CannedRoutesTransport.Error` | `missingRequestURL`, `noMatch`, `ambiguousMatch(count: Int)` |
| `MatchingTransport.MatchingTransportError` | `notMatched` |

---

## Utilities

### EndpointAnyEncodable : Encodable, Sendable
```swift
public init<T: Encodable & Sendable>(_ value: T)
```
Type-erased `Encodable` wrapper for endpoint body dictionaries.

### DateDecodingStrategies
```swift
public static let iso8601FractionalAndNonFractionalSeconds: JSONDecoder.DateDecodingStrategy
```
Handles both `2024-01-01T12:34:56Z` and `2024-01-01T12:34:56.789Z`.

### DateEncodingStrategies
```swift
public static let iso8601FractionalSeconds: JSONEncoder.DateEncodingStrategy
```
Encodes as ISO8601 with fractional seconds.
