//  GentleNetworkingTests.swift
//  Jonathan Ritchey

import Testing
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

@Suite("HTTPMethod")
struct HTTPMethodTests {
    @Test("raw values")
    func rawValues() async throws {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.post.rawValue == "POST")
        #expect(HTTPMethod.put.rawValue == "PUT")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
        #expect(HTTPMethod.patch.rawValue == "PATCH")
    }
}

// MARK: - Endpoint Tests

@Suite("Endpoint")
struct EndpointTests {
    let baseURL = URL(string: "https://api.example.com")!

    @Test("initialization")
    func initialization() async throws {
        let endpoint = Endpoint(
            path: "/users",
            method: .get,
            query: [URLQueryItem(name: "page", value: "1")],
            body: ["key": "value"],
            requiresAuth: true
        )

        #expect(endpoint.path == "/users")
        #expect(endpoint.method == .get)
        #expect(endpoint.query?.count == 1)
        #expect(endpoint.query?.first?.name == "page")
        #expect((endpoint.body?["key"] as? String) == "value")
        #expect(endpoint.requiresAuth)
    }

    @Test("default requiresAuth is false")
    func defaultRequiresAuth() async throws {
        let endpoint = Endpoint(path: "/public", method: .get)
        #expect(endpoint.requiresAuth == false)
    }

    @Test("from creates correct URL")
    func fromCreatesCorrectURL() async throws {
        let endpoint = Endpoint(path: "/users/123", method: .get)
        let request = endpoint.from(baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/users/123")
    }

    @Test("from sets HTTP method")
    func fromSetsHTTPMethod() async throws {
        let methods: [HTTPMethod] = [.get, .post, .put, .delete, .patch]
        for method in methods {
            let endpoint = Endpoint(path: "/test", method: method)
            let request = endpoint.from(baseURL)
            #expect(request.httpMethod == method.rawValue)
        }
    }

    @Test("from includes query params")
    func fromIncludesQueryParams() async throws {
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
        #expect(urlString.contains("q=swift"))
        #expect(urlString.contains("page=2"))
    }

    @Test("from sets body and content-type")
    func fromSetsBodyAndContentType() async throws {
        let endpoint = Endpoint(
            path: "/users",
            method: .post,
            body: ["name": "John", "email": "john@example.com"]
        )
        let request = endpoint.from(baseURL)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        let json = try #require(try? JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "John")
        #expect(json["email"] as? String == "john@example.com")
    }

    @Test("from handles nil query")
    func fromHandlesNilQuery() async throws {
        let endpoint = Endpoint(path: "/users", method: .get, query: nil)
        let request = endpoint.from(baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/users")
    }

    @Test("from handles empty query")
    func fromHandlesEmptyQuery() async throws {
        let endpoint = Endpoint(path: "/users", method: .get, query: [])
        let request = endpoint.from(baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/users")
    }
}

// MARK: - APIEnvironment Tests

@Suite("APIEnvironment")
struct APIEnvironmentTests {
    @Test("stores baseURL")
    func storesBaseURL() async throws {
        let url = URL(string: "https://api.test.com")
        let env = DefaultAPIEnvironment(baseURL: url)
        #expect(env._baseURL == url)
        #expect(env.baseURL == url)
    }

    @Test("allows nil baseURL")
    func allowsNilBaseURL() async throws {
        let env = DefaultAPIEnvironment(baseURL: nil)
        #expect(env._baseURL == nil)
    }

    @Test("is Equatable")
    func isEquatable() async throws {
        let url = URL(string: "https://api.test.com")
        let env1 = DefaultAPIEnvironment(baseURL: url)
        let env2 = DefaultAPIEnvironment(baseURL: url)
        let env3 = DefaultAPIEnvironment(baseURL: URL(string: "https://other.com"))
        #expect(env1 == env2)
        #expect(env1 != env3)
    }
}

// MARK: - MockKeyChainStore Tests

@Suite("MockKeyChainStore")
struct MockKeyChainStoreTests {
    @Test("save and retrieve")
    func saveAndRetrieve() async throws {
        let store = MockKeyChainStore()
        try store.save("secret-token", forKey: "accessToken")
        let retrieved = try store.value(forKey: "accessToken")
        #expect(retrieved == "secret-token")
    }

    @Test("missing key returns nil")
    func missingKeyReturnsNil() async throws {
        let store = MockKeyChainStore()
        let value = try store.value(forKey: "nonexistent")
        #expect(value == nil)
    }

    @Test("delete removes value")
    func deleteRemovesValue() async throws {
        let store = MockKeyChainStore()
        try store.save("token", forKey: "key")
        #expect(try store.value(forKey: "key") == "token")
        try store.deleteValue(forKey: "key")
        #expect(try store.value(forKey: "key") == nil)
    }

    @Test("delete nonexistent does not throw")
    func deleteNonexistentDoesNotThrow() async throws {
        let store = MockKeyChainStore()
        do {
            try store.deleteValue(forKey: "nonexistent")
        } catch {
            Issue.record("Unexpected throw: \(error)")
        }
    }

    @Test("overwrite value")
    func overwriteValue() async throws {
        let store = MockKeyChainStore()
        try store.save("old-token", forKey: "accessToken")
        try store.save("new-token", forKey: "accessToken")
        let value = try store.value(forKey: "accessToken")
        #expect(value == "new-token")
    }

    @Test("multiple keys")
    func multipleKeys() async throws {
        let store = MockKeyChainStore()
        try store.save("token1", forKey: "key1")
        try store.save("token2", forKey: "key2")
        #expect(try store.value(forKey: "key1") == "token1")
        #expect(try store.value(forKey: "key2") == "token2")
        try store.deleteValue(forKey: "key1")
        #expect(try store.value(forKey: "key1") == nil)
        #expect(try store.value(forKey: "key2") == "token2")
    }
}

// MARK: - KeyChainStoreError Tests

@Suite("KeyChainStoreError")
struct KeyChainStoreErrorTests {
    @Test("error cases exist and conform to Error")
    func errorCasesExist() async throws {
        // Verify error cases can be created and used
        let encodingError: any Error = KeyChainStoreError.stringEncodingFailed
        let decodingError: any Error = KeyChainStoreError.stringDecodingFailed
        let statusError: any Error = KeyChainStoreError.unexpectedStatus(-25300)

        #expect(encodingError is KeyChainStoreError)
        #expect(decodingError is KeyChainStoreError)
        #expect(statusError is KeyChainStoreError)
    }
}

private enum TestEnvironment {
    static var isSwiftPMTest: Bool {
        // SwiftPM sets this for test runs. Host-app tests will also set it,
        // but the entitlement difference is what determines behavior. You can
        // refine this check with a custom env var if needed.
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

@Suite("SystemKeyChainStore under SwiftPM vs Host App")
struct SystemKeyChainStoreEnvironmentTests {
    let service = "com.example.gentlenetworking.tests"

    @Test("save/value/delete branches by environment")
    func saveValueDelete() async {
        let store = SystemKeyChainStore(service: service)

        if TestEnvironment.isSwiftPMTest {
            // Expect missing entitlement (-34018) in pure SwiftPM runs
            do {
                try store.save("value", forKey: "k")
                Issue.record("Expected missing entitlement error, but save succeeded")
            } catch KeyChainStoreError.unexpectedStatus(let status) {
                #expect(status == errSecMissingEntitlement)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            do {
                _ = try store.value(forKey: "k")
                Issue.record("Expected missing entitlement error, but value() succeeded")
            } catch KeyChainStoreError.unexpectedStatus(let status) {
                #expect(status == errSecMissingEntitlement)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            do {
                try store.deleteValue(forKey: "k")
                Issue.record("Expected missing entitlement error, but delete succeeded")
            } catch KeyChainStoreError.unexpectedStatus(let status) {
                // Deleting may also report missing entitlement
                #expect(status == errSecMissingEntitlement)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        } else {
            // In a host app with entitlements, expect normal success path
            do {
                try store.save("value", forKey: "k")
                let v = try store.value(forKey: "k")
                #expect(v == "value")
                try store.deleteValue(forKey: "k")
                let missing = try store.value(forKey: "k")
                #expect(missing == nil)
            } catch {
                Issue.record("Unexpected error in entitled environment: \(error)")
            }
        }
    }
}

// MARK: - SystemKeyChainStore Tests

//@Suite("SystemKeyChainStore")
//struct SystemKeyChainStoreTests {
//    // Use a unique service identifier for tests to avoid conflicts
//    private static let testService = "com.gentlenetworking.tests.\(UUID().uuidString)"
//
//    /// Helper to create a store with clean state
//    private func makeStore() -> SystemKeyChainStore {
//        SystemKeyChainStore(service: Self.testService)
//    }
//
//    /// Helper to clean up a key after test
//    private func cleanup(key: String, store: SystemKeyChainStore) {
//        try? store.deleteValue(forKey: key)
//    }
//
//    @Test("save and retrieve")
//    func saveAndRetrieve() async throws {
//        let store = makeStore()
//        let key = "test-save-retrieve-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        try store.save("secret-token", forKey: key)
//        let retrieved = try store.value(forKey: key)
//        #expect(retrieved == "secret-token")
//    }
//
//    @Test("missing key returns nil")
//    func missingKeyReturnsNil() async throws {
//        let store = makeStore()
//        let value = try store.value(forKey: "nonexistent-key-\(UUID().uuidString)")
//        #expect(value == nil)
//    }
//
//    @Test("delete removes value")
//    func deleteRemovesValue() async throws {
//        let store = makeStore()
//        let key = "test-delete-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        try store.save("token", forKey: key)
//        #expect(try store.value(forKey: key) == "token")
//        try store.deleteValue(forKey: key)
//        #expect(try store.value(forKey: key) == nil)
//    }
//
//    @Test("delete nonexistent does not throw")
//    func deleteNonexistentDoesNotThrow() async throws {
//        let store = makeStore()
//        do {
//            try store.deleteValue(forKey: "nonexistent-\(UUID().uuidString)")
//        } catch {
//            Issue.record("Unexpected throw: \(error)")
//        }
//    }
//
//    @Test("overwrite value")
//    func overwriteValue() async throws {
//        let store = makeStore()
//        let key = "test-overwrite-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        try store.save("old-token", forKey: key)
//        try store.save("new-token", forKey: key)
//        let value = try store.value(forKey: key)
//        #expect(value == "new-token")
//    }
//
//    @Test("multiple keys")
//    func multipleKeys() async throws {
//        let store = makeStore()
//        let key1 = "test-multi-1-\(UUID().uuidString)"
//        let key2 = "test-multi-2-\(UUID().uuidString)"
//        defer {
//            cleanup(key: key1, store: store)
//            cleanup(key: key2, store: store)
//        }
//
//        try store.save("token1", forKey: key1)
//        try store.save("token2", forKey: key2)
//        #expect(try store.value(forKey: key1) == "token1")
//        #expect(try store.value(forKey: key2) == "token2")
//        try store.deleteValue(forKey: key1)
//        #expect(try store.value(forKey: key1) == nil)
//        #expect(try store.value(forKey: key2) == "token2")
//    }
//
//    @Test("stores unicode strings")
//    func storesUnicodeStrings() async throws {
//        let store = makeStore()
//        let key = "test-unicode-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        let unicodeValue = "Hello 世界 🌍 émoji"
//        try store.save(unicodeValue, forKey: key)
//        let retrieved = try store.value(forKey: key)
//        #expect(retrieved == unicodeValue)
//    }
//
//    @Test("stores empty string")
//    func storesEmptyString() async throws {
//        let store = makeStore()
//        let key = "test-empty-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        try store.save("", forKey: key)
//        let retrieved = try store.value(forKey: key)
//        #expect(retrieved == "")
//    }
//
//    @Test("stores long string")
//    func storesLongString() async throws {
//        let store = makeStore()
//        let key = "test-long-\(UUID().uuidString)"
//        defer { cleanup(key: key, store: store) }
//
//        let longValue = String(repeating: "a", count: 10000)
//        try store.save(longValue, forKey: key)
//        let retrieved = try store.value(forKey: key)
//        #expect(retrieved == longValue)
//    }
//
//    @Test("different services are isolated")
//    func differentServicesAreIsolated() async throws {
//        let service1 = "com.test.service1.\(UUID().uuidString)"
//        let service2 = "com.test.service2.\(UUID().uuidString)"
//        let store1 = SystemKeyChainStore(service: service1)
//        let store2 = SystemKeyChainStore(service: service2)
//        let key = "shared-key"
//        defer {
//            try? store1.deleteValue(forKey: key)
//            try? store2.deleteValue(forKey: key)
//        }
//
//        try store1.save("value-from-service-1", forKey: key)
//        try store2.save("value-from-service-2", forKey: key)
//
//        #expect(try store1.value(forKey: key) == "value-from-service-1")
//        #expect(try store2.value(forKey: key) == "value-from-service-2")
//    }
//
//    @Test("uses default service from bundle identifier")
//    func usesDefaultService() async throws {
//        // Just verify the initializer works with default parameter
//        let store = SystemKeyChainStore()
//        // We can't easily test the actual service name, but we can verify it works
//        let key = "test-default-service-\(UUID().uuidString)"
//        defer { try? store.deleteValue(forKey: key) }
//
//        try store.save("test-value", forKey: key)
//        let retrieved = try store.value(forKey: key)
//        #expect(retrieved == "test-value")
//    }
//}

// MARK: - Mock Auth Service for Testing

struct MockAuthService: AuthServiceProtocol {
    let keyChainStore: KeyChainStoreProtocol

    init(keyChainStore: KeyChainStoreProtocol = MockKeyChainStore()) {
        self.keyChainStore = keyChainStore
    }
}

// MARK: - AuthService Tests

@Suite("AuthService")
struct AuthServiceTests {
    @Test("default header field")
    func defaultHeaderField() async throws {
        let service = MockAuthService()
        #expect(service.headerField == "Authorization")
    }

    @Test("default header value prefix")
    func defaultHeaderValuePrefix() async throws {
        let service = MockAuthService()
        #expect(service.headerValuePrefix == "Bearer ")
    }

    @Test("default keychain key")
    func defaultKeyChainKey() async throws {
        let service = MockAuthService()
        #expect(service.keyChainKey == "accessToken")
    }

    @Test("save access token")
    func saveAccessToken() async throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)
        try service.saveAccessToken("my-jwt-token")
        let stored = try store.value(forKey: "accessToken")
        #expect(stored == "my-jwt-token")
    }

    @Test("load access token")
    func loadAccessToken() async throws {
        let store = MockKeyChainStore()
        try store.save("stored-token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        let token = try service.loadAccessToken()
        #expect(token == "stored-token")
    }

    @Test("load access token returns nil")
    func loadAccessTokenReturnsNil() async throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)
        let token = try service.loadAccessToken()
        #expect(token == nil)
    }

    @Test("authorize adds header")
    func authorizeAddsHeader() async throws {
        let store = MockKeyChainStore()
        try store.save("test-token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        var request = URLRequest(url: URL(string: "https://api.example.com/users")!)
        request = try service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("authorize preserves headers")
    func authorizePreservesHeaders() async throws {
        let store = MockKeyChainStore()
        try store.save("token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request = try service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test("authorize without token")
    func authorizeWithoutToken() async throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)
        var request = URLRequest(url: URL(string: "https://api.example.com")!)
        request = try service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("delete access token")
    func deleteAccessToken() async throws {
        let store = MockKeyChainStore()
        try store.save("token-to-delete", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        try service.deleteAccessToken()
        let token = try service.loadAccessToken()
        #expect(token == nil)
    }
}

// MARK: - DateDecodingStrategies Tests

@Suite("DateDecodingStrategies")
struct DateDecodingStrategiesTests {
    @Test("decodes standard ISO8601")
    func decodesStandardISO8601() async throws {
        let json = """
        {"id": 1, "name": "Test", "createdAt": "2024-06-15T10:30:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        let user = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))
        #expect(user.id == 1)
        #expect(user.name == "Test")
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: user.createdAt)
        #expect(components.year == 2024)
        #expect(components.month == 6)
        #expect(components.day == 15)
        #expect(components.hour == 10)
        #expect(components.minute == 30)
    }

    @Test("decodes fractional ISO8601")
    func decodesFractionalISO8601() async throws {
        let json = """
        {"id": 2, "name": "Fractional", "createdAt": "2024-12-01T14:45:30.123Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        let user = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))
        #expect(user.id == 2)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: user.createdAt)
        #expect(components.year == 2024)
        #expect(components.month == 12)
        #expect(components.day == 1)
        #expect(components.hour == 14)
        #expect(components.minute == 45)
        #expect(components.second == 30)
    }

    @Test("throws for invalid date")
    func throwsForInvalidDate() throws {
        let json = """
        {"id": 3, "name": "Invalid", "createdAt": "not-a-date"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))
        }
    }
}

// MARK: - MockNetworkService Tests

@Suite("MockNetworkService")
struct MockNetworkServiceTests {
    let testEnvironment = DefaultAPIEnvironment(baseURL: URL(string: "https://api.test.com"))
    let testEndpoint = Endpoint(path: "/users", method: .get)

    @Test("request decodes single model")
    func requestDecodesSingleModel() async throws {
        let json = """
        {"id": 1, "name": "John Doe", "email": "john@example.com"}
        """
        let service = MockNetworkService(responseJSON: json)
        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
        #expect(user.name == "John Doe")
        #expect(user.email == "john@example.com")
    }

    @Test("requestModels decodes array")
    func requestModelsDecodesArray() async throws {
        let json = """
        [
            {"id": 1, "name": "Alice", "email": "alice@example.com"},
            {"id": 2, "name": "Bob", "email": "bob@example.com"}
        ]
        """
        let service = MockNetworkService(responseJSON: json)
        let users: [TestUser] = try await service.requestModels(to: testEndpoint, via: testEnvironment)
        #expect(users.count == 2)
        #expect(users[0].name == "Alice")
        #expect(users[1].name == "Bob")
    }

    @Test("requestVoid returns success")
    func requestVoidReturnsSuccess() async throws {
        let service = MockNetworkService(responseJSON: "")
        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)
        switch result {
        case .success(let code):
            #expect(code == 200)
        }
    }

    @Test("applies delay")
    func appliesDelay() async throws {
        let json = """
        {"id": 1, "name": "Test", "email": "test@test.com"}
        """
        let service = MockNetworkService(
            responseJSON: json,
            duration: Duration.milliseconds(100)
        )
        let start = ContinuousClock.now
        let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        let elapsed = ContinuousClock.now - start
        #expect(elapsed >= .milliseconds(90))
    }

    @Test("throws decoding error")
    func throwsDecodingError() async {
        let invalidJSON = "not valid json"
        let service = MockNetworkService(responseJSON: invalidJSON)
        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            Issue.record("Should have thrown")
        } catch {
            #expect(error is DecodingError)
        }
    }

    @Test("uses custom date decoding")
    func usesCustomDateDecoding() async throws {
        let json = """
        {"id": 1, "name": "Dated", "createdAt": "2024-03-15T08:00:00.500Z"}
        """
        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        let service = MockNetworkService(
            responseJSON: json,
            jsonDecoder: customDecoder
        )
        let user: TestUserWithDate = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
    }
}

// MARK: - NetworkError Tests

@Suite("NetworkError")
struct NetworkErrorTests {
    @Test("stores status code")
    func storesStatusCode() async throws {
        let error = NetworkError.invalidStatusCode(404)
        if case .invalidStatusCode(let code) = error {
            #expect(code == 404)
        } else {
            Issue.record("Wrong error case")
        }
    }

    @Test("can be nil")
    func canBeNil() async throws {
        let error = NetworkError.invalidStatusCode(nil)
        if case .invalidStatusCode(let code) = error {
            #expect(code == nil)
        } else {
            Issue.record("Wrong error case")
        }
    }

    @Test("conforms to Error")
    func conformsToError() async throws {
        let error: Error = NetworkError.invalidStatusCode(500)
        #expect(error is NetworkError)
    }
}

// MARK: - NetworkServiceEmptyResponseResult Tests

@Suite("NetworkServiceEmptyResponseResult")
struct NetworkServiceEmptyResponseResultTests {
    @Test("success stores code")
    func successStoresCode() async throws {
        let result = NetworkServiceEmptyResponseResult.success(code: 204)
        if case .success(let code) = result {
            #expect(code == 204)
        } else {
            Issue.record("Wrong result case")
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

@Suite("HTTPNetworkService", .serialized)
struct HTTPNetworkServiceTests {
    let testEnvironment = DefaultAPIEnvironment(baseURL: URL(string: "https://api.test.com"))
    let testEndpoint = Endpoint(path: "/users", method: .get)

    func makeTestTransport() -> HTTPTransportProtocol {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let transport = URLSessionTransport(
            session: URLSession(configuration: config)
        )
        return transport
    }

    @Test("request decodes response")
    func requestDecodesResponse() async throws {
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
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService()
        )
        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
        #expect(user.name == "Test User")
        #expect(user.email == "test@example.com")
    }

    @Test("requestModels decodes array")
    func requestModelsDecodesArray() async throws {
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
        let service = HTTPNetworkService(
            transport: makeTestTransport(),
            authService: MockAuthService()
        )
        let users: [TestUser] = try await service.requestModels(to: testEndpoint, via: testEnvironment)
        #expect(users.count == 2)
        #expect(users[0].id == 1)
        #expect(users[1].id == 2)
    }

    @Test("requestVoid returns success (200)")
    func requestVoidReturnsSuccess() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let service = HTTPNetworkService(
            transport: makeTestTransport(),
            authService: MockAuthService()
        )
        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)
        switch result {
        case .success(let code):
            #expect(code == 200)
        }
    }

    @Test("requestVoid returns success (204)")
    func requestVoidReturnsSuccessFor204() async throws {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let service = HTTPNetworkService(
            transport: makeTestTransport(),
            authService: MockAuthService()
        )
        let result = try await service.requestVoid(to: testEndpoint, via: testEnvironment)
        switch result {
        case .success(let code):
            #expect(code == 204)
        }
    }

    @Test("throws for 404")
    func throwsFor404() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService()
        )
        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            Issue.record("Should have thrown")
        } catch let error as NetworkError {
            if case .invalidStatusCode(let code) = error {
                #expect(code == 404)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("throws for 500")
    func throwsFor500() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService()
        )
        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            Issue.record("Should have thrown")
        } catch let error as NetworkError {
            if case .invalidStatusCode(let code) = error {
                #expect(code == 500)
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    @Test("calls invalidation handler on 401")
    func callsInvalidationHandlerOn401() async {
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
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService(),
            invalidationHandler: handler
        )
        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            Issue.record("Should have thrown")
        } catch {
            // expected
        }
        #expect(handler.invalidationCalled)
    }

    @Test("adds auth header when required")
    func addsAuthHeader() async throws {
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
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService(keyChainStore: store)
        )
        let authEndpoint = Endpoint(path: "/protected", method: .get, requiresAuth: true)
        let _: TestUser = try await service.request(to: authEndpoint, via: testEnvironment)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-bearer-token")
    }

    @Test("omits auth header when not required")
    func noAuthHeader() async throws {
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
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService(keyChainStore: store)
        )
        let publicEndpoint = Endpoint(path: "/public", method: .get, requiresAuth: false)
        let _: TestUser = try await service.request(to: publicEndpoint, via: testEnvironment)
        #expect(capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("uses custom decoder")
    func usesCustomDecoder() async throws {
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
            enum CodingKeys: String, CodingKey { case id, name; case createdAt = "created_at" }
        }
        let customDecoder = JSONDecoder()
        customDecoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService(),
            jsonDecoder: customDecoder
        )
        let user: SnakeCaseUser = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
        #expect(user.name == "Custom")
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

@Suite("Custom EndpointProtocol")
struct CustomEndpointTests {
    let baseURL = URL(string: "https://api.example.com")!

    @Test("get users endpoint")
    func getUsersEndpoint() async throws {
        let endpoint = APIEndpoint.getUsers
        let request = endpoint.from(baseURL)
        #expect(request.url?.path == "/users")
        #expect(request.httpMethod == "GET")
        #expect(endpoint.requiresAuth == false)
    }

    @Test("get user endpoint")
    func getUserEndpoint() async throws {
        let endpoint = APIEndpoint.getUser(id: 42)
        let request = endpoint.from(baseURL)
        #expect(request.url?.path == "/users/42")
        #expect(request.httpMethod == "GET")
        #expect(endpoint.requiresAuth)
    }

    @Test("create user endpoint")
    func createUserEndpoint() async throws {
        let endpoint = APIEndpoint.createUser(name: "John", email: "john@test.com")
        let request = endpoint.from(baseURL)
        #expect(request.url?.path == "/users")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        let json = try #require(try? JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "John")
        #expect(json["email"] as? String == "john@test.com")
    }

    @Test("delete user endpoint")
    func deleteUserEndpoint() async throws {
        let endpoint = APIEndpoint.deleteUser(id: 99)
        let request = endpoint.from(baseURL)
        #expect(request.url?.path == "/users/99")
        #expect(request.httpMethod == "DELETE")
        #expect(endpoint.requiresAuth)
    }
}

