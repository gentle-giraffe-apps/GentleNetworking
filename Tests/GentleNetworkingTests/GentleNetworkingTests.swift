//  GentleNetworkingTests.swift
//  Jonathan Ritchey

import XCTest
import Foundation
@testable import GentleNetworking

// MARK: - Test Models

struct TestUser: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
}

struct TestUserWithDate: Codable, Equatable {
    let id: Int
    let name: String
    let createdAt: Date
}

// MARK: - HTTPMethod Tests

final class HTTPMethodTests: XCTestCase {
    func testRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
    }
}

// MARK: - Endpoint Tests

final class EndpointTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.com")!

    func testInitialization() {
        let endpoint = Endpoint(
            path: "/users",
            method: .get,
            query: [URLQueryItem(name: "page", value: "1")],
            body: ["key": "value"],
            requiresAuth: true
        )

        XCTAssertEqual(endpoint.path, "/users")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.query?.count, 1)
        XCTAssertEqual(endpoint.query?.first?.name, "page")
        XCTAssertEqual(endpoint.body?["key"] as? String, "value")
        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testDefaultRequiresAuth() {
        let endpoint = Endpoint(path: "/public", method: .get)
        XCTAssertFalse(endpoint.requiresAuth)
    }

    func testFromCreatesCorrectURL() {
        let endpoint = Endpoint(path: "/users/123", method: .get)
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users/123")
    }

    func testFromSetsHTTPMethod() {
        let methods: [HTTPMethod] = [.get, .post, .put, .delete, .patch]

        for method in methods {
            let endpoint = Endpoint(path: "/test", method: method)
            let request = endpoint.from(baseURL)
            XCTAssertEqual(request.httpMethod, method.rawValue)
        }
    }

    func testFromIncludesQueryParams() {
        let endpoint = Endpoint(
            path: "/search",
            method: .get,
            query: [
                URLQueryItem(name: "q", value: "swift"),
                URLQueryItem(name: "page", value: "2")
            ]
        )
        let request = endpoint.from(baseURL)

        let urlString = request.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("q=swift"))
        XCTAssertTrue(urlString.contains("page=2"))
    }

    func testFromSetsBodyAndContentType() {
        let endpoint = Endpoint(
            path: "/users",
            method: .post,
            body: ["name": "John", "email": "john@example.com"]
        )
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)

        // Verify body content
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(json["name"] as? String, "John")
            XCTAssertEqual(json["email"] as? String, "john@example.com")
        } else {
            XCTFail("Failed to parse body JSON")
        }
    }

    func testFromHandlesNilQuery() {
        let endpoint = Endpoint(path: "/users", method: .get, query: nil)
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users")
    }

    func testFromHandlesEmptyQuery() {
        let endpoint = Endpoint(path: "/users", method: .get, query: [])
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.absoluteString, "https://api.example.com/users")
    }
}

// MARK: - APIEnvironment Tests

final class APIEnvironmentTests: XCTestCase {
    func testStoresBaseURL() {
        let url = URL(string: "https://api.test.com")
        let env = DefaultAPIEnvironment(baseURL: url)

        XCTAssertEqual(env._baseURL, url)
        XCTAssertEqual(env.baseURL, url)
    }

    func testAllowsNilBaseURL() {
        let env = DefaultAPIEnvironment(baseURL: nil)
        XCTAssertNil(env._baseURL)
    }

    func testIsEquatable() {
        let url = URL(string: "https://api.test.com")
        let env1 = DefaultAPIEnvironment(baseURL: url)
        let env2 = DefaultAPIEnvironment(baseURL: url)
        let env3 = DefaultAPIEnvironment(baseURL: URL(string: "https://other.com"))

        XCTAssertEqual(env1, env2)
        XCTAssertNotEqual(env1, env3)
    }
}

// MARK: - MockKeyChainStore Tests

final class MockKeyChainStoreTests: XCTestCase {
    func testSaveAndRetrieve() throws {
        let store = MockKeyChainStore()

        try store.save("secret-token", forKey: "accessToken")
        let retrieved = try store.value(forKey: "accessToken")

        XCTAssertEqual(retrieved, "secret-token")
    }

    func testMissingKeyReturnsNil() throws {
        let store = MockKeyChainStore()

        let value = try store.value(forKey: "nonexistent")
        XCTAssertNil(value)
    }

    func testDeleteRemovesValue() throws {
        let store = MockKeyChainStore()

        try store.save("token", forKey: "key")
        XCTAssertEqual(try store.value(forKey: "key"), "token")

        try store.deleteValue(forKey: "key")
        XCTAssertNil(try store.value(forKey: "key"))
    }

    func testDeleteNonexistentDoesNotThrow() throws {
        let store = MockKeyChainStore()

        XCTAssertNoThrow(try store.deleteValue(forKey: "nonexistent"))
    }

    func testOverwriteValue() throws {
        let store = MockKeyChainStore()

        try store.save("old-token", forKey: "accessToken")
        try store.save("new-token", forKey: "accessToken")

        let value = try store.value(forKey: "accessToken")
        XCTAssertEqual(value, "new-token")
    }

    func testMultipleKeys() throws {
        let store = MockKeyChainStore()

        try store.save("token1", forKey: "key1")
        try store.save("token2", forKey: "key2")

        XCTAssertEqual(try store.value(forKey: "key1"), "token1")
        XCTAssertEqual(try store.value(forKey: "key2"), "token2")

        try store.deleteValue(forKey: "key1")

        XCTAssertNil(try store.value(forKey: "key1"))
        XCTAssertEqual(try store.value(forKey: "key2"), "token2")
    }
}

// MARK: - KeyChainStoreError Tests

final class KeyChainStoreErrorTests: XCTestCase {
    func testErrorCasesExist() {
        let encodingError = KeyChainStoreError.stringEncodingFailed
        let decodingError = KeyChainStoreError.stringDecodingFailed
        let statusError = KeyChainStoreError.unexpectedStatus(-25300)

        // Verify they are Error types
        XCTAssertTrue(encodingError is Error)
        XCTAssertTrue(decodingError is Error)
        XCTAssertTrue(statusError is Error)
    }
}

// MARK: - Mock Auth Service for Testing

struct MockAuthService: AuthServiceProtocol {
    let keyChainStore: KeyChainStoreProtocol

    init(keyChainStore: KeyChainStoreProtocol = MockKeyChainStore()) {
        self.keyChainStore = keyChainStore
    }
}

// MARK: - AuthService Tests

final class AuthServiceTests: XCTestCase {
    func testDefaultHeaderField() {
        let service = MockAuthService()
        XCTAssertEqual(service.headerField, "Authorization")
    }

    func testDefaultHeaderValuePrefix() {
        let service = MockAuthService()
        XCTAssertEqual(service.headerValuePrefix, "Bearer ")
    }

    func testDefaultKeyChainKey() {
        let service = MockAuthService()
        XCTAssertEqual(service.keyChainKey, "accessToken")
    }

    func testSaveAccessToken() throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)

        try service.saveAccessToken("my-jwt-token")

        let stored = try store.value(forKey: "accessToken")
        XCTAssertEqual(stored, "my-jwt-token")
    }

    func testLoadAccessToken() throws {
        let store = MockKeyChainStore()
        try store.save("stored-token", forKey: "accessToken")

        let service = MockAuthService(keyChainStore: store)
        let token = try service.loadAccessToken()

        XCTAssertEqual(token, "stored-token")
    }

    func testLoadAccessTokenReturnsNil() throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)

        let token = try service.loadAccessToken()
        XCTAssertNil(token)
    }

    func testAuthorizeAddsHeader() throws {
        let store = MockKeyChainStore()
        try store.save("test-token", forKey: "accessToken")

        let service = MockAuthService(keyChainStore: store)

        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        request = try service.authorize(request)

        let authHeader = request.value(forHTTPHeaderField: "Authorization")
        XCTAssertEqual(authHeader, "Bearer test-token")
    }

    func testAuthorizePreservesHeaders() throws {
        let store = MockKeyChainStore()
        try store.save("token", forKey: "accessToken")

        let service = MockAuthService(keyChainStore: store)

        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request = try service.authorize(request)

        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testAuthorizeWithoutToken() throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)

        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request = try service.authorize(request)

        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testDeleteAccessToken() throws {
        let store = MockKeyChainStore()
        try store.save("token-to-delete", forKey: "accessToken")

        let service = MockAuthService(keyChainStore: store)
        try service.deleteAccessToken()

        let token = try service.loadAccessToken()
        XCTAssertNil(token)
    }
}

// MARK: - DateDecodingStrategies Tests

final class DateDecodingStrategiesTests: XCTestCase {
    func testDecodesStandardISO8601() throws {
        let json = """
        {"id": 1, "name": "Test", "createdAt": "2024-06-15T10:30:00Z"}
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds

        let user = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "Test")

        // Verify date components
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: user.createdAt)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 30)
    }

    func testDecodesFractionalISO8601() throws {
        let json = """
        {"id": 2, "name": "Fractional", "createdAt": "2024-12-01T14:45:30.123Z"}
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds

        let user = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))

        XCTAssertEqual(user.id, 2)

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: user.createdAt)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.second, 30)
    }

    func testThrowsForInvalidDate() {
        let json = """
        {"id": 3, "name": "Invalid", "createdAt": "not-a-date"}
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds

        XCTAssertThrowsError(try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}

// MARK: - MockNetworkService Tests

final class MockNetworkServiceTests: XCTestCase {
    let testEnvironment = DefaultAPIEnvironment(baseURL: URL(string: "https://api.test.com"))
    let testEndpoint = Endpoint(path: "/users", method: .get)

    func testRequestDecodesSingleModel() async throws {
        let json = """
        {"id": 1, "name": "John Doe", "email": "john@example.com"}
        """

        let service = MockNetworkService(responseJSON: json, delayInMilliseconds: 0)
        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "John Doe")
        XCTAssertEqual(user.email, "john@example.com")
    }

    func testRequestModelsDecodesArray() async throws {
        let json = """
        [
            {"id": 1, "name": "Alice", "email": "alice@example.com"},
            {"id": 2, "name": "Bob", "email": "bob@example.com"}
        ]
        """

        let service = MockNetworkService(responseJSON: json, delayInMilliseconds: 0)
        let users: [TestUser] = try await service.requestModels(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0].name, "Alice")
        XCTAssertEqual(users[1].name, "Bob")
    }

    func testRequestVoidReturnsSuccess() async throws {
        let service = MockNetworkService(responseJSON: "", delayInMilliseconds: 0)
        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)

        if case .success(let code) = result {
            XCTAssertEqual(code, 200)
        } else {
            XCTFail("Expected success result")
        }
    }

    func testAppliesDelay() async throws {
        let json = """
        {"id": 1, "name": "Test", "email": "test@test.com"}
        """

        let service = MockNetworkService(responseJSON: json, delayInMilliseconds: 100)

        let start = ContinuousClock.now
        let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        let elapsed = ContinuousClock.now - start

        XCTAssertGreaterThanOrEqual(elapsed, .milliseconds(90)) // Allow some tolerance
    }

    func testThrowsDecodingError() async {
        let invalidJSON = "not valid json"
        let service = MockNetworkService(responseJSON: invalidJSON, delayInMilliseconds: 0)

        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testUsesCustomDateDecoding() async throws {
        let json = """
        {"id": 1, "name": "Dated", "createdAt": "2024-03-15T08:00:00.500Z"}
        """

        let service = MockNetworkService(responseJSON: json, delayInMilliseconds: 0)
        let user: TestUserWithDate = try await service.request(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(user.id, 1)
        // If date decoded correctly, test passes
    }
}

// MARK: - NetworkError Tests

final class NetworkErrorTests: XCTestCase {
    func testStoresStatusCode() {
        let error = NetworkError.invalidStatusCode(404)

        if case .invalidStatusCode(let code) = error {
            XCTAssertEqual(code, 404)
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testCanBeNil() {
        let error = NetworkError.invalidStatusCode(nil)

        if case .invalidStatusCode(let code) = error {
            XCTAssertNil(code)
        } else {
            XCTFail("Wrong error case")
        }
    }

    func testConformsToError() {
        let error: Error = NetworkError.invalidStatusCode(500)
        XCTAssertTrue(error is NetworkError)
    }
}

// MARK: - NetworkServiceEmptyResponseResult Tests

final class NetworkServiceEmptyResponseResultTests: XCTestCase {
    func testSuccessStoresCode() {
        let result = NetworkServiceEmptyResponseResult.success(code: 204)

        if case .success(let code) = result {
            XCTAssertEqual(code, 204)
        } else {
            XCTFail("Wrong result case")
        }
    }
}

// MARK: - HTTPNetworkService Integration Tests (with URLProtocol Mock)

/// Mock URLProtocol for testing HTTPNetworkService
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Mock Token Invalidation Handler for testing
final class MockTokenInvalidationHandler: TokenInvalidationHandler, @unchecked Sendable {
    var invalidationCalled = false

    func handleInvalidToken() async {
        invalidationCalled = true
    }
}

final class HTTPNetworkServiceTests: XCTestCase {
    let testEnvironment = DefaultAPIEnvironment(baseURL: URL(string: "https://api.test.com"))
    let testEndpoint = Endpoint(path: "/users", method: .get)

    func makeTestSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testRequestDecodesResponse() async throws {
        let json = """
        {"id": 1, "name": "Test User", "email": "test@example.com"}
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
    }

    func testRequestModelsDecodesArray() async throws {
        let json = """
        [{"id": 1, "name": "User 1", "email": "u1@test.com"}, {"id": 2, "name": "User 2", "email": "u2@test.com"}]
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        let users: [TestUser] = try await service.requestModels(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0].id, 1)
        XCTAssertEqual(users[1].id, 2)
    }

    func testRequestVoidReturnsSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)

        if case .success(let code) = result {
            XCTAssertEqual(code, 200)
        } else {
            XCTFail("Expected success")
        }
    }

    func testRequestVoidReturnsSuccessFor204() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)

        if case .success(let code) = result {
            XCTAssertEqual(code, 204)
        } else {
            XCTFail("Expected success")
        }
    }

    func testThrowsFor404() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            if case .invalidStatusCode(let code) = error {
                XCTAssertEqual(code, 404)
            } else {
                XCTFail("Wrong error case")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testThrowsFor500() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService()
        )

        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            if case .invalidStatusCode(let code) = error {
                XCTAssertEqual(code, 500)
            }
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func testCallsInvalidationHandlerOn401() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let handler = MockTokenInvalidationHandler()
        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService(),
            invalidationHandler: handler
        )

        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            XCTFail("Should have thrown")
        } catch {
            // Expected
        }

        XCTAssertTrue(handler.invalidationCalled)
    }

    func testAddsAuthHeader() async throws {
        let json = """
        {"id": 1, "name": "Auth User", "email": "auth@test.com"}
        """

        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let store = MockKeyChainStore()
        try store.save("test-bearer-token", forKey: "accessToken")

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService(keyChainStore: store)
        )

        let authEndpoint = Endpoint(path: "/protected", method: .get, requiresAuth: true)
        let _: TestUser = try await service.request(to: authEndpoint, via: testEnvironment)

        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-bearer-token")
    }

    func testNoAuthHeader() async throws {
        let json = """
        {"id": 1, "name": "Public User", "email": "public@test.com"}
        """

        var capturedRequest: URLRequest?

        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        let store = MockKeyChainStore()
        try store.save("token", forKey: "accessToken")

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService(keyChainStore: store)
        )

        let publicEndpoint = Endpoint(path: "/public", method: .get, requiresAuth: false)
        let _: TestUser = try await service.request(to: publicEndpoint, via: testEnvironment)

        XCTAssertNil(capturedRequest?.value(forHTTPHeaderField: "Authorization"))
    }

    func testUsesCustomDecoder() async throws {
        let json = """
        {"id": 1, "name": "Custom", "created_at": "2024-01-15T12:00:00Z"}
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(json.utf8))
        }

        struct SnakeCaseUser: Decodable {
            let id: Int
            let name: String
            let createdAt: Date

            enum CodingKeys: String, CodingKey {
                case id, name
                case createdAt = "created_at"
            }
        }

        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds

        let session = makeTestSession()
        let service = HTTPNetworkService(
            session: session,
            authService: MockAuthService(),
            jsonDecoder: customDecoder
        )

        let user: SnakeCaseUser = try await service.request(to: testEndpoint, via: testEnvironment)

        XCTAssertEqual(user.id, 1)
        XCTAssertEqual(user.name, "Custom")
    }
}

// MARK: - Custom EndpointProtocol Implementation Tests

/// Example of custom endpoint enum
enum APIEndpoint: EndpointProtocol {
    case getUsers
    case getUser(id: Int)
    case createUser(name: String, email: String)
    case deleteUser(id: Int)

    var path: String {
        switch self {
        case .getUsers:
            return "/users"
        case .getUser(let id):
            return "/users/\(id)"
        case .createUser:
            return "/users"
        case .deleteUser(let id):
            return "/users/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUsers, .getUser:
            return .get
        case .createUser:
            return .post
        case .deleteUser:
            return .delete
        }
    }

    var query: [URLQueryItem]? {
        return nil
    }

    var body: [String: Any]? {
        switch self {
        case .createUser(let name, let email):
            return ["name": name, "email": email]
        default:
            return nil
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .getUsers:
            return false
        default:
            return true
        }
    }
}

final class CustomEndpointTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.com")!

    func testGetUsersEndpoint() {
        let endpoint = APIEndpoint.getUsers
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.path, "/users")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertFalse(endpoint.requiresAuth)
    }

    func testGetUserEndpoint() {
        let endpoint = APIEndpoint.getUser(id: 42)
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.path, "/users/42")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(endpoint.requiresAuth)
    }

    func testCreateUserEndpoint() {
        let endpoint = APIEndpoint.createUser(name: "John", email: "john@test.com")
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.path, "/users")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            XCTAssertEqual(json["name"] as? String, "John")
            XCTAssertEqual(json["email"] as? String, "john@test.com")
        } else {
            XCTFail("Failed to parse body")
        }
    }

    func testDeleteUserEndpoint() {
        let endpoint = APIEndpoint.deleteUser(id: 99)
        let request = endpoint.from(baseURL)

        XCTAssertEqual(request.url?.path, "/users/99")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertTrue(endpoint.requiresAuth)
    }
}
