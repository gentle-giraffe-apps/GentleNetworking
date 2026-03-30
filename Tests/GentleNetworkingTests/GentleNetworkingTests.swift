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
    @Test("initialization")
    func initialization() async throws {
        let endpoint = Endpoint(
            path: "/users",
            method: .get,
            query: [URLQueryItem(name: "page", value: "1")],
            body: ["key": EndpointAnyEncodable("value")],
            requiresAuth: true
        )

        #expect(endpoint.path == "/users")
        #expect(endpoint.method == .get)
        #expect(endpoint.query?.count == 1)
        #expect(endpoint.query?.first?.name == "page")
        // #expect((endpoint.body?["key"] as? String) == "value")
        #expect(endpoint.requiresAuth)
    }

    @Test("default requiresAuth is false")
    func defaultRequiresAuth() async throws {
        let endpoint = Endpoint(path: "/public", method: .get)
        #expect(endpoint.requiresAuth == false)
    }

    @Test("from creates correct URL")
    func fromCreatesCorrectURL() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = Endpoint(path: "/users/123", method: .get)
        let request = try endpoint.from(baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/users/123")
    }

    @Test("from sets HTTP method")
    func fromSetsHTTPMethod() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let methods: [HTTPMethod] = [.get, .post, .put, .delete, .patch]
        for method in methods {
            let endpoint = Endpoint(path: "/test", method: method)
            let request = try endpoint.from(baseURL)
            #expect(request.httpMethod == method.rawValue)
        }
    }

    @Test("from includes query params")
    func fromIncludesQueryParams() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = Endpoint(
            path: "/search",
            method: .get,
            query: [
                URLQueryItem(name: "q", value: "swift"),
                URLQueryItem(name: "page", value: "2")
            ]
        )
        let request = try endpoint.from(baseURL)

        let urlString = request.url?.absoluteString ?? ""
        #expect(urlString.contains("q=swift"))
        #expect(urlString.contains("page=2"))
    }

    @Test("from sets body and content-type")
    func fromSetsBodyAndContentType() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = Endpoint(
            path: "/users",
            method: .post,
            body: [
                "name": EndpointAnyEncodable("John"),
                "email": EndpointAnyEncodable("john@example.com")
            ]
        )
        let request = try endpoint.from(baseURL)

        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try #require(request.httpBody)
        let json = try #require(try? JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "John")
        #expect(json["email"] as? String == "john@example.com")
    }

    @Test("from handles nil query")
    func fromHandlesNilQuery() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = Endpoint(path: "/users", method: .get, query: nil)
        let request = try endpoint.from(baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/users")
    }

    @Test("from handles empty query")
    func fromHandlesEmptyQuery() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = Endpoint(path: "/users", method: .get, query: [])
        let request = try endpoint.from(baseURL)
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
        try await store.save("secret-token", forKey: "accessToken")
        let retrieved = try await store.value(forKey: "accessToken")
        #expect(retrieved == "secret-token")
    }

    @Test("missing key returns nil")
    func missingKeyReturnsNil() async throws {
        let store = MockKeyChainStore()
        let value = try await store.value(forKey: "nonexistent")
        #expect(value == nil)
    }

    @Test("delete removes value")
    func deleteRemovesValue() async throws {
        let store = MockKeyChainStore()
        try await store.save("token", forKey: "key")
        #expect(try await store.value(forKey: "key") == "token")
        try await store.deleteValue(forKey: "key")
        #expect(try await store.value(forKey: "key") == nil)
    }

    @Test("delete nonexistent does not throw")
    func deleteNonexistentDoesNotThrow() async throws {
        let store = MockKeyChainStore()
        do {
            try await store.deleteValue(forKey: "nonexistent")
        } catch {
            Issue.record("Unexpected throw: \(error)")
        }
    }

    @Test("overwrite value")
    func overwriteValue() async throws {
        let store = MockKeyChainStore()
        try await store.save("old-token", forKey: "accessToken")
        try await store.save("new-token", forKey: "accessToken")
        let value = try await store.value(forKey: "accessToken")
        #expect(value == "new-token")
    }

    @Test("multiple keys")
    func multipleKeys() async throws {
        let store = MockKeyChainStore()
        try await store.save("token1", forKey: "key1")
        try await store.save("token2", forKey: "key2")
        #expect(try await store.value(forKey: "key1") == "token1")
        #expect(try await store.value(forKey: "key2") == "token2")
        try await store.deleteValue(forKey: "key1")
        #expect(try await store.value(forKey: "key1") == nil)
        #expect(try await store.value(forKey: "key2") == "token2")
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
                try await store.save("value", forKey: "k")
                Issue.record("Expected missing entitlement error, but save succeeded")
            } catch KeyChainStoreError.unexpectedStatus(let status) {
                #expect(status == errSecMissingEntitlement)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            do {
                _ = try await store.value(forKey: "k")
                Issue.record("Expected missing entitlement error, but value() succeeded")
            } catch KeyChainStoreError.unexpectedStatus(let status) {
                #expect(status == errSecMissingEntitlement)
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            do {
                try await store.deleteValue(forKey: "k")
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
                try await store.save("value", forKey: "k")
                let v = try await store.value(forKey: "k")
                #expect(v == "value")
                try await store.deleteValue(forKey: "k")
                let missing = try await store.value(forKey: "k")
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
        try await service.saveAccessToken("my-jwt-token")
        let stored = try await store.value(forKey: "accessToken")
        #expect(stored == "my-jwt-token")
    }

    @Test("load access token")
    func loadAccessToken() async throws {
        let store = MockKeyChainStore()
        try await store.save("stored-token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        let token = try await service.loadAccessToken()
        #expect(token == "stored-token")
    }

    @Test("load access token returns nil")
    func loadAccessTokenReturnsNil() async throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)
        let token = try await service.loadAccessToken()
        #expect(token == nil)
    }

    @Test("authorize adds header")
    func authorizeAddsHeader() async throws {
        let store = MockKeyChainStore()
        try await store.save("test-token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request = try await service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("authorize preserves headers")
    func authorizePreservesHeaders() async throws {
        let store = MockKeyChainStore()
        try await store.save("token", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        let url = try #require(URL(string: "https://api.example.com"))
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request = try await service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test("authorize without token")
    func authorizeWithoutToken() async throws {
        let store = MockKeyChainStore()
        let service = MockAuthService(keyChainStore: store)
        let url = try #require(URL(string: "https://api.example.com"))
        var request = URLRequest(url: url)
        request = try await service.authorize(request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("delete access token")
    func deleteAccessToken() async throws {
        let store = MockKeyChainStore()
        try await store.save("token-to-delete", forKey: "accessToken")
        let service = MockAuthService(keyChainStore: store)
        try await service.deleteAccessToken()
        let token = try await service.loadAccessToken()
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
        let utc = try #require(TimeZone(identifier: "UTC"))
        let components = calendar.dateComponents(in: utc, from: user.createdAt)
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
        let utc = try #require(TimeZone(identifier: "UTC"))
        let components = calendar.dateComponents(in: utc, from: user.createdAt)
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

    @Test("fallback to standard format when fractional fails")
    func fallbackToStandardFormat() async throws {
        // This date uses standard ISO8601 without fractional seconds
        // The fractional formatter will fail, but the standard formatter should succeed
        let json = """
        {"id": 4, "name": "Standard", "createdAt": "2024-03-20T15:45:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = DateDecodingStrategies.iso8601FractionalAndNonFractionalSeconds
        let user = try decoder.decode(TestUserWithDate.self, from: Data(json.utf8))
        #expect(user.id == 4)
        #expect(user.name == "Standard")
        let calendar = Calendar(identifier: .gregorian)
        let utc = try #require(TimeZone(identifier: "UTC"))
        let components = calendar.dateComponents(in: utc, from: user.createdAt)
        #expect(components.year == 2024)
        #expect(components.month == 3)
        #expect(components.day == 20)
        #expect(components.hour == 15)
        #expect(components.minute == 45)
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
    @Test("wraps HTTPStatusError")
    func wrapsHTTPStatusError() async throws {
        let error = NetworkError.httpStatusError(.notFound)
        if case .httpStatusError(let statusError) = error {
            #expect(statusError == .notFound)
            #expect(statusError.statusCode == 404)
        } else {
            Issue.record("Wrong error case")
        }
    }

    @Test("conforms to Error")
    func conformsToError() async throws {
        let error: Error = NetworkError.httpStatusError(.internalServerError)
        #expect(error is NetworkError)
    }
}

// MARK: - HTTPStatusError Tests

@Suite("HTTPStatusError")
struct HTTPStatusErrorTests {
    @Test("maps 401 to unauthorized")
    func maps401() {
        #expect(HTTPStatusError(statusCode: 401) == .unauthorized)
    }

    @Test("maps 403 to forbidden")
    func maps403() {
        #expect(HTTPStatusError(statusCode: 403) == .forbidden)
    }

    @Test("maps 404 to notFound")
    func maps404() {
        #expect(HTTPStatusError(statusCode: 404) == .notFound)
    }

    @Test("maps 429 to rateLimited")
    func maps429() {
        #expect(HTTPStatusError(statusCode: 429) == .rateLimited)
    }

    @Test("maps 500 to internalServerError")
    func maps500() {
        #expect(HTTPStatusError(statusCode: 500) == .internalServerError)
    }

    @Test("maps 503 to serviceUnavailable")
    func maps503() {
        #expect(HTTPStatusError(statusCode: 503) == .serviceUnavailable)
    }

    @Test("maps 302 to redirect")
    func maps302() {
        #expect(HTTPStatusError(statusCode: 302) == .redirect(302))
    }

    @Test("maps 418 to clientError")
    func maps418() {
        #expect(HTTPStatusError(statusCode: 418) == .clientError(418))
    }

    @Test("maps 502 to serverError")
    func maps502() {
        #expect(HTTPStatusError(statusCode: 502) == .serverError(502))
    }

    @Test("maps unknown code above 599 to serverError")
    func mapsUnknownCode() {
        #expect(HTTPStatusError(statusCode: 600) == .serverError(600))
    }

    @Test("returns nil for 200")
    func returnsNilFor200() {
        #expect(HTTPStatusError(statusCode: 200) == nil)
    }

    @Test("returns nil for 299")
    func returnsNilFor299() {
        #expect(HTTPStatusError(statusCode: 299) == nil)
    }

    @Test("statusCode round-trips for all named cases")
    func statusCodeRoundTrips() {
        let cases: [(HTTPStatusError, Int)] = [
            (.unauthorized, 401),
            (.forbidden, 403),
            (.notFound, 404),
            (.rateLimited, 429),
            (.internalServerError, 500),
            (.serviceUnavailable, 503),
            (.clientError(400), 400),
            (.serverError(502), 502),
            (.redirect(301), 301),
        ]
        for (error, expected) in cases {
            #expect(error.statusCode == expected)
        }
    }

    @Test("conforms to Error")
    func conformsToError() {
        let error: Error = HTTPStatusError.notFound
        #expect(error is HTTPStatusError)
    }

    @Test("conforms to Sendable")
    func conformsToSendable() {
        let error: any Sendable = HTTPStatusError.unauthorized
        _ = error
    }

    @Test("conforms to Equatable")
    func conformsToEquatable() {
        #expect(HTTPStatusError.notFound == HTTPStatusError.notFound)
        #expect(HTTPStatusError.clientError(400) == HTTPStatusError.clientError(400))
        #expect(HTTPStatusError.notFound != HTTPStatusError.forbidden)
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            ))
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
    func throwsFor404() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            ))
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
            if case .httpStatusError(let statusError) = error {
                #expect(statusError == .notFound)
                #expect(statusError.statusCode == 404)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("throws for 500")
    func throwsFor500() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            ))
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
            if case .httpStatusError(let statusError) = error {
                #expect(statusError == .internalServerError)
                #expect(statusError.statusCode == 500)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type")
        }
    }

    @Test("calls invalidation handler on 401")
    func callsInvalidationHandlerOn401() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(json.utf8))
        }
        let store = MockKeyChainStore()
        try await store.save("test-bearer-token", forKey: "accessToken")
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(json.utf8))
        }
        let store = MockKeyChainStore()
        try await store.save("token", forKey: "accessToken")
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
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ))
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

    @Test("handles 401 with nil invalidation handler")
    func handles401WithNilHandler() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data())
        }
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService(),
            invalidationHandler: nil  // nil handler
        )
        do {
            let _: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
            Issue.record("Should have thrown")
        } catch let error as NetworkError {
            if case .httpStatusError(let statusError) = error {
                #expect(statusError == .unauthorized)
                #expect(statusError.statusCode == 401)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("accepts status code 201")
    func acceptsStatusCode201() async throws {
        let json = """
        {"id": 1, "name": "Created", "email": "created@test.com"}
        """
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 201,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(json.utf8))
        }
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService()
        )
        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
        #expect(user.name == "Created")
    }

    @Test("accepts status code 299 (upper boundary)")
    func acceptsStatusCode299() async throws {
        let json = """
        {"id": 1, "name": "Boundary", "email": "boundary@test.com"}
        """
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 299,
                httpVersion: nil,
                headerFields: nil
            ))
            return (response, Data(json.utf8))
        }
        let transport = makeTestTransport()
        let service = HTTPNetworkService(
            transport: transport,
            authService: MockAuthService()
        )
        let user: TestUser = try await service.request(to: testEndpoint, via: testEnvironment)
        #expect(user.id == 1)
        #expect(user.name == "Boundary")
    }

    @Test("rejects status code 300 (just outside success range)")
    func rejectsStatusCode300() async throws {
        MockURLProtocol.requestHandler = { request in
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: 300,
                httpVersion: nil,
                headerFields: nil
            ))
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
            if case .httpStatusError(let statusError) = error {
                #expect(statusError == .redirect(300))
                #expect(statusError.statusCode == 300)
            } else {
                Issue.record("Wrong error case")
            }
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
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

    var body: [String: EndpointAnyEncodable]? {
        switch self {
        case .createUser(let name, let email):
            return [
                "name": EndpointAnyEncodable(name),
                "email": EndpointAnyEncodable(email)
            ]
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

// MARK: - RequestPattern Tests

@Suite("RequestPattern")
struct RequestPatternTests {
    @Test("matches with nil method accepts any HTTP method")
    func nilMethodMatchesAny() async throws {
        let pattern = RequestPattern(method: nil, pathRegex: "/users")

        let getURL = try #require(URL(string: "https://api.example.com/users"))
        var getRequest = URLRequest(url: getURL)
        getRequest.httpMethod = "GET"
        #expect(pattern.matches(getRequest))

        let postURL = try #require(URL(string: "https://api.example.com/users"))
        var postRequest = URLRequest(url: postURL)
        postRequest.httpMethod = "POST"
        #expect(pattern.matches(postRequest))

        let deleteURL = try #require(URL(string: "https://api.example.com/users"))
        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.httpMethod = "DELETE"
        #expect(pattern.matches(deleteRequest))
    }

    @Test("returns false for request with no URL")
    func noURLReturnsFalse() async throws {
        let pattern = RequestPattern(method: .get, pathRegex: "/users")
        // Create a request without URL by using init(url:) with a valid URL then setting it to nil
        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request.url = nil
        #expect(!pattern.matches(request))
    }

    @Test("nil hostRegex matches any host")
    func nilHostMatchesAny() async throws {
        let pattern = RequestPattern(method: .get, hostRegex: nil, pathRegex: "/api")

        let url1 = try #require(URL(string: "https://example.com/api"))
        var request1 = URLRequest(url: url1)
        request1.httpMethod = "GET"
        #expect(pattern.matches(request1))

        let url2 = try #require(URL(string: "https://different.org/api"))
        var request2 = URLRequest(url: url2)
        request2.httpMethod = "GET"
        #expect(pattern.matches(request2))
    }

    @Test("method mismatch returns false")
    func methodMismatchReturnsFalse() async throws {
        let pattern = RequestPattern(method: .post, pathRegex: "/users")

        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        #expect(!pattern.matches(request))
    }

    @Test("hostRegex filters by host")
    func hostRegexFilters() async throws {
        let pattern = RequestPattern(method: .get, hostRegex: "api\\.example\\.com", pathRegex: "/users")

        let matchURL = try #require(URL(string: "https://api.example.com/users"))
        var matchRequest = URLRequest(url: matchURL)
        matchRequest.httpMethod = "GET"
        #expect(pattern.matches(matchRequest))

        let noMatchURL = try #require(URL(string: "https://other.com/users"))
        var noMatchRequest = URLRequest(url: noMatchURL)
        noMatchRequest.httpMethod = "GET"
        #expect(!pattern.matches(noMatchRequest))
    }

    @Test("literal initializer escapes special characters")
    func literalInitializerEscapes() async throws {
        let pattern = RequestPattern(method: .get, host: "api.example.com", path: "/users/123")

        let url = try #require(URL(string: "https://api.example.com/users/123"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        #expect(pattern.matches(request))

        // Should NOT match partial paths (regex is anchored)
        let partialURL = try #require(URL(string: "https://api.example.com/users/1234"))
        var partialRequest = URLRequest(url: partialURL)
        partialRequest.httpMethod = "GET"
        #expect(!pattern.matches(partialRequest))
    }

    @Test("path mismatch returns false")
    func pathMismatchReturnsFalse() async throws {
        let pattern = RequestPattern(method: .get, pathRegex: "^/users$")

        let url = try #require(URL(string: "https://api.example.com/posts"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        #expect(!pattern.matches(request))
    }
}

// MARK: - CannedRoutesTransport Tests

@Suite("CannedRoutesTransport")
struct CannedRoutesTransportTests {
    @Test("firstMatchWins returns first matching route")
    func firstMatchWins() async throws {
        let route1 = CannedRoute(
            pattern: RequestPattern(method: .get, pathRegex: "/users"),
            response: CannedResponse(string: "route1")
        )
        let route2 = CannedRoute(
            pattern: RequestPattern(method: .get, pathRegex: "/users"),
            response: CannedResponse(string: "route2")
        )

        let transport = CannedRoutesTransport(routes: [route1, route2], mode: .firstMatchWins)
        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "route1")
        #expect(response.statusCode == 200)
    }

    @Test("requireUniqueMatch throws ambiguousMatch for multiple matches")
    func ambiguousMatchThrows() async throws {
        let route1 = CannedRoute(
            pattern: RequestPattern(method: .get, pathRegex: "/users"),
            response: CannedResponse(string: "route1")
        )
        let route2 = CannedRoute(
            pattern: RequestPattern(method: .get, pathRegex: "/users"),
            response: CannedResponse(string: "route2")
        )

        let transport = CannedRoutesTransport(routes: [route1, route2], mode: .requireUniqueMatch)
        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            _ = try await transport.data(for: request)
            Issue.record("Should have thrown ambiguousMatch")
        } catch CannedRoutesTransport.Error.ambiguousMatch(let count) {
            #expect(count == 2)
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("throws noMatch when no routes match")
    func noMatchThrows() async throws {
        let route = CannedRoute(
            pattern: RequestPattern(method: .post, pathRegex: "/users"),
            response: CannedResponse(string: "response")
        )

        let transport = CannedRoutesTransport(routes: [route], mode: .firstMatchWins)
        let url = try #require(URL(string: "https://api.example.com/other"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            _ = try await transport.data(for: request)
            Issue.record("Should have thrown noMatch")
        } catch CannedRoutesTransport.Error.noMatch {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("throws missingRequestURL when request has no URL")
    func missingURLThrows() async throws {
        let route = CannedRoute(
            pattern: RequestPattern(pathRegex: "/users"),
            response: CannedResponse(string: "response")
        )

        let transport = CannedRoutesTransport(routes: [route])
        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request.url = nil

        do {
            _ = try await transport.data(for: request)
            Issue.record("Should have thrown missingRequestURL")
        } catch CannedRoutesTransport.Error.missingRequestURL {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("requireUniqueMatch succeeds with exactly one match")
    func requireUniqueMatchSucceeds() async throws {
        let route = CannedRoute(
            pattern: RequestPattern(method: .get, pathRegex: "/users"),
            response: CannedResponse(string: "unique", statusCode: 201)
        )

        let transport = CannedRoutesTransport(routes: [route], mode: .requireUniqueMatch)
        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "unique")
        #expect(response.statusCode == 201)
    }
}

// MARK: - CannedResponseTransport Tests

@Suite("CannedResponseTransport")
struct CannedResponseTransportTests {
    @Test("returns canned response for valid request")
    func returnsCannedResponse() async throws {
        let transport = CannedResponseTransport(string: "test response", statusCode: 201)
        let url = try #require(URL(string: "https://api.example.com/test"))
        let request = URLRequest(url: url)

        let (data, response) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "test response")
        #expect(response.statusCode == 201)
    }

    @Test("throws missingRequestURL when request has no URL")
    func missingURLThrows() async throws {
        let transport = CannedResponseTransport(string: "response")
        let url = try #require(URL(string: "https://example.com"))
        var request = URLRequest(url: url)
        request.url = nil

        do {
            _ = try await transport.data(for: request)
            Issue.record("Should have thrown missingRequestURL")
        } catch CannedResponseTransport.Error.missingRequestURL {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }

    @Test("CannedResponse with custom headers")
    func customHeaders() async throws {
        let response = CannedResponse(
            string: "json data",
            statusCode: 200,
            headerFields: ["Content-Type": "application/json"]
        )
        let transport = CannedResponseTransport(cannedResponse: response)
        let url = try #require(URL(string: "https://api.example.com/data"))
        let request = URLRequest(url: url)

        let (_, urlResponse) = try await transport.data(for: request)
        #expect(urlResponse.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }
}

// MARK: - MatchingTransport Tests

@Suite("MatchingTransport")
struct MatchingTransportTests {
    @Test("passes request to underlying transport when pattern matches")
    func passesWhenMatches() async throws {
        let pattern = RequestPattern(method: .get, pathRegex: "/users")
        let innerTransport = CannedResponseTransport(string: "matched", statusCode: 200)
        let transport = MatchingTransport(pattern: pattern, transport: innerTransport)

        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "matched")
        #expect(response.statusCode == 200)
    }

    @Test("throws notMatched when pattern does not match")
    func throwsWhenNotMatched() async throws {
        let pattern = RequestPattern(method: .post, pathRegex: "/users")
        let innerTransport = CannedResponseTransport(string: "response")
        let transport = MatchingTransport(pattern: pattern, transport: innerTransport)

        let url = try #require(URL(string: "https://api.example.com/users"))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            _ = try await transport.data(for: request)
            Issue.record("Should have thrown notMatched")
        } catch MatchingTransport.MatchingTransportError.notMatched {
            // Expected
        } catch {
            Issue.record("Wrong error type: \(error)")
        }
    }
}

// MARK: - DateEncodingStrategies Tests

@Suite("DateEncodingStrategies")
struct DateEncodingStrategiesTests {
    @Test("encodes date with fractional seconds")
    func encodesFractionalSeconds() async throws {
        struct DateContainer: Codable {
            let date: Date
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = DateEncodingStrategies.iso8601FractionalSeconds

        // Create a specific date
        let components = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2024, month: 6, day: 15,
            hour: 10, minute: 30, second: 45,
            nanosecond: 123_000_000
        )
        let date = try #require(components.date)
        let container = DateContainer(date: date)

        let data = try encoder.encode(container)
        let json = try #require(String(data: data, encoding: .utf8))

        // Should contain fractional seconds format
        #expect(json.contains("2024-06-15T10:30:45"))
        #expect(json.contains("Z"))
    }
}

// MARK: - Custom EndpointProtocol Tests

@Suite("Custom EndpointProtocol")
struct CustomEndpointTests {
    @Test("get users endpoint")
    func getUsersEndpoint() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = APIEndpoint.getUsers
        let request = try endpoint.from(baseURL)
        #expect(request.url?.path == "/users")
        #expect(request.httpMethod == "GET")
        #expect(endpoint.requiresAuth == false)
    }

    @Test("get user endpoint")
    func getUserEndpoint() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = APIEndpoint.getUser(id: 42)
        let request = try endpoint.from(baseURL)
        #expect(request.url?.path == "/users/42")
        #expect(request.httpMethod == "GET")
        #expect(endpoint.requiresAuth)
    }

    @Test("create user endpoint")
    func createUserEndpoint() async throws {
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = APIEndpoint.createUser(name: "John", email: "john@test.com")
        let request = try endpoint.from(baseURL)
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
        let baseURL = try #require(URL(string: "https://api.example.com"))
        let endpoint = APIEndpoint.deleteUser(id: 99)
        let request = try endpoint.from(baseURL)
        #expect(request.url?.path == "/users/99")
        #expect(request.httpMethod == "DELETE")
        #expect(endpoint.requiresAuth)
    }
}

// MARK: - SSL Pinning

private struct SucceedingEvaluator: ServerTrustEvaluator {
    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        // Always succeeds
    }
}

private struct FailingEvaluator: ServerTrustEvaluator {
    func evaluate(_ trust: SecTrust, forHost host: String) throws {
        throw ServerTrustError.certificatePinningFailed(host: host)
    }
}

@Suite("ServerTrustError")
struct ServerTrustErrorTests {

    @Test("trustEvaluationFailed is an Error")
    func trustEvaluationFailed() {
        let error: any Error = ServerTrustError.trustEvaluationFailed
        #expect(error is ServerTrustError)
    }

    @Test("noCertificateFound is an Error")
    func noCertificateFound() {
        let error: any Error = ServerTrustError.noCertificateFound
        #expect(error is ServerTrustError)
    }

    @Test("noPublicKeyFound is an Error")
    func noPublicKeyFound() {
        let error: any Error = ServerTrustError.noPublicKeyFound
        #expect(error is ServerTrustError)
    }

    @Test("certificatePinningFailed stores host")
    func certificatePinningFailedHost() {
        let error = ServerTrustError.certificatePinningFailed(host: "api.example.com")
        if case .certificatePinningFailed(let host) = error {
            #expect(host == "api.example.com")
        } else {
            Issue.record("Wrong error case")
        }
    }
}

@Suite("PublicKeyPinningEvaluator")
struct PublicKeyPinningEvaluatorTests {

    @Test("init stores pinned hashes")
    func initStoresHashes() {
        let hash = Data([0x01, 0x02, 0x03])
        let evaluator = PublicKeyPinningEvaluator(pinnedKeyHashes: [hash])
        #expect(evaluator.pinnedKeyHashes.count == 1)
        #expect(evaluator.pinnedKeyHashes.contains(hash))
    }

    @Test("empty hashes set is valid")
    func emptyHashes() {
        let evaluator = PublicKeyPinningEvaluator(pinnedKeyHashes: [])
        #expect(evaluator.pinnedKeyHashes.isEmpty)
    }

    @Test("multiple hashes are stored")
    func multipleHashes() {
        let hash1 = Data([0x01])
        let hash2 = Data([0x02])
        let evaluator = PublicKeyPinningEvaluator(pinnedKeyHashes: [hash1, hash2])
        #expect(evaluator.pinnedKeyHashes.count == 2)
    }
}

@Suite("CertificatePinningEvaluator")
struct CertificatePinningEvaluatorTests {

    @Test("init stores pinned certificates")
    func initStoresCerts() {
        let cert = Data([0xAA, 0xBB, 0xCC])
        let evaluator = CertificatePinningEvaluator(pinnedCertificates: [cert])
        #expect(evaluator.pinnedCertificates.count == 1)
        #expect(evaluator.pinnedCertificates.contains(cert))
    }

    @Test("empty certificates set is valid")
    func emptyCerts() {
        let evaluator = CertificatePinningEvaluator(pinnedCertificates: [])
        #expect(evaluator.pinnedCertificates.isEmpty)
    }
}

@Suite("PinningTransport")
struct PinningTransportTests {

    @Test("conforms to HTTPTransportProtocol")
    func conformsToProtocol() {
        let transport: any HTTPTransportProtocol = PinningTransport(pinnedDomains: [:])
        _ = transport
    }

    @Test("initializes with empty pinned domains")
    func emptyDomains() {
        _ = PinningTransport(pinnedDomains: [:])
    }

    @Test("initializes with custom configuration")
    func customConfiguration() {
        let config = URLSessionConfiguration.ephemeral
        _ = PinningTransport(pinnedDomains: [:], configuration: config)
    }

    @Test("initializes with pinned domains")
    func pinnedDomains() {
        _ = PinningTransport(
            pinnedDomains: ["api.example.com": SucceedingEvaluator()]
        )
    }

    @Test("initializes with multiple pinned domains")
    func multiplePinnedDomains() {
        _ = PinningTransport(
            pinnedDomains: [
                "api.example.com": SucceedingEvaluator(),
                "cdn.example.com": FailingEvaluator()
            ]
        )
    }
}

@Suite("ServerTrustEvaluator conformance")
struct ServerTrustEvaluatorConformanceTests {

    @Test("succeeding evaluator conforms to protocol")
    func succeedingEvaluator() {
        let evaluator: any ServerTrustEvaluator = SucceedingEvaluator()
        _ = evaluator
    }

    @Test("failing evaluator conforms to protocol")
    func failingEvaluator() {
        let evaluator: any ServerTrustEvaluator = FailingEvaluator()
        _ = evaluator
    }
}

// MARK: - RetryTransport Tests

private final class SequenceTransport: HTTPTransportProtocol, @unchecked Sendable {
    private var responses: [(Data, HTTPURLResponse)]
    private var errors: [Error?]
    private(set) var callCount = 0

    init(responses: [(Data, HTTPURLResponse)], errors: [Error?]? = nil) {
        self.responses = responses
        self.errors = errors ?? Array(repeating: nil, count: responses.count)
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let index = callCount
        callCount += 1
        if let error = errors[index] {
            throw error
        }
        return responses[index]
    }
}

private func makeResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
    try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil))
}

@Suite("RetryTransport")
struct RetryTransportTests {

    @Test("succeeds on first attempt without retrying")
    func noRetryOnSuccess() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let response = try makeResponse(url: url, statusCode: 200)
        let inner = SequenceTransport(responses: [(Data("ok".utf8), response)])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (data, resp) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(resp.statusCode == 200)
        #expect(inner.callCount == 1)
    }

    @Test("retries on 500 and succeeds")
    func retriesOnServerError() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let fail = try makeResponse(url: url, statusCode: 500)
        let ok = try makeResponse(url: url, statusCode: 200)
        let inner = SequenceTransport(responses: [
            (Data("err".utf8), fail),
            (Data("ok".utf8), ok)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (data, resp) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(resp.statusCode == 200)
        #expect(inner.callCount == 2)
    }

    @Test("retries on 503 and succeeds")
    func retriesOnServiceUnavailable() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let fail = try makeResponse(url: url, statusCode: 503)
        let ok = try makeResponse(url: url, statusCode: 200)
        let inner = SequenceTransport(responses: [
            (Data("err".utf8), fail),
            (Data("err".utf8), fail),
            (Data("ok".utf8), ok)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 200)
        #expect(inner.callCount == 3)
    }

    @Test("retries on 429 rate limited")
    func retriesOnRateLimited() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let fail = try makeResponse(url: url, statusCode: 429)
        let ok = try makeResponse(url: url, statusCode: 200)
        let inner = SequenceTransport(responses: [
            (Data("slow".utf8), fail),
            (Data("ok".utf8), ok)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 200)
        #expect(inner.callCount == 2)
    }

    @Test("does not retry on 404")
    func noRetryOn404() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let notFound = try makeResponse(url: url, statusCode: 404)
        let inner = SequenceTransport(responses: [
            (Data("nope".utf8), notFound)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 404)
        #expect(inner.callCount == 1)
    }

    @Test("does not retry on 401")
    func noRetryOn401() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let unauth = try makeResponse(url: url, statusCode: 401)
        let inner = SequenceTransport(responses: [
            (Data("unauth".utf8), unauth)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 401)
        #expect(inner.callCount == 1)
    }

    @Test("exhausts retries and returns last server error response")
    func exhaustsRetries() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let fail = try makeResponse(url: url, statusCode: 500)
        let inner = SequenceTransport(responses: [
            (Data("err".utf8), fail),
            (Data("err".utf8), fail),
            (Data("err".utf8), fail),
            (Data("err".utf8), fail)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 500)
        #expect(inner.callCount == 4) // 1 initial + 3 retries
    }

    @Test("retries on network-level error and succeeds")
    func retriesOnNetworkError() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let ok = try makeResponse(url: url, statusCode: 200)
        let networkErr = URLError(.notConnectedToInternet)
        let inner = SequenceTransport(
            responses: [
                (Data(), ok), // placeholder, won't be used
                (Data("ok".utf8), ok)
            ],
            errors: [networkErr, nil]
        )
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 3, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (data, resp) = try await transport.data(for: request)
        #expect(String(data: data, encoding: .utf8) == "ok")
        #expect(resp.statusCode == 200)
        #expect(inner.callCount == 2)
    }

    @Test("respects maxRetries of zero")
    func zeroRetries() async throws {
        let url = try #require(URL(string: "https://api.example.com/test"))
        let fail = try makeResponse(url: url, statusCode: 500)
        let inner = SequenceTransport(responses: [
            (Data("err".utf8), fail)
        ])
        let transport = RetryTransport(inner: inner, policy: RetryPolicy(maxRetries: 0, baseDelay: 0.01))
        let request = URLRequest(url: url)

        let (_, resp) = try await transport.data(for: request)
        #expect(resp.statusCode == 500)
        #expect(inner.callCount == 1)
    }

    @Test("conforms to HTTPTransportProtocol")
    func conformsToProtocol() {
        let transport: any HTTPTransportProtocol = RetryTransport()
        _ = transport
    }

    @Test("default policy retries up to 3 times with full jitter")
    func defaultPolicyMaxRetries() {
        let policy = RetryPolicy()
        #expect(policy.maxRetries == 3)
        #expect(policy.baseDelay == 0.5)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.jitter == .full)
    }
}

@Suite("JitterStrategy")
struct JitterStrategyTests {

    @Test("nil jitter returns pure exponential delay")
    func noJitter() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 60.0, jitter: nil)
        for _ in 0..<50 {
            // attempt 0: 1.0, attempt 1: 2.0, attempt 2: 4.0
            #expect(policy.delay(forAttempt: 0, previousDelay: 1.0) == 1.0)
            #expect(policy.delay(forAttempt: 1, previousDelay: 1.0) == 2.0)
            #expect(policy.delay(forAttempt: 2, previousDelay: 2.0) == 4.0)
        }
    }

    @Test("nil jitter respects maxDelay cap")
    func noJitterCapped() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 3.0, jitter: nil)
        #expect(policy.delay(forAttempt: 10, previousDelay: 3.0) == 3.0)
    }

    @Test("full jitter produces values in 0...exponentialDelay")
    func fullJitter() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 5.0, jitter: .full)
        for _ in 0..<100 {
            let d0 = policy.delay(forAttempt: 0, previousDelay: 1.0)
            #expect(d0 >= 0 && d0 <= 1.0)
            let d3 = policy.delay(forAttempt: 3, previousDelay: 4.0)
            #expect(d3 >= 0 && d3 <= 5.0) // capped at maxDelay
        }
    }

    @Test("equal jitter guarantees minimum half of exponential delay")
    func equalJitter() {
        let policy = RetryPolicy(baseDelay: 2.0, maxDelay: 60.0, jitter: .equal)
        for _ in 0..<100 {
            // attempt 0: exponential = 2.0, half = 1.0, range [1.0...2.0]
            let d0 = policy.delay(forAttempt: 0, previousDelay: 2.0)
            #expect(d0 >= 1.0 && d0 <= 2.0)
            // attempt 1: exponential = 4.0, half = 2.0, range [2.0...4.0]
            let d1 = policy.delay(forAttempt: 1, previousDelay: 2.0)
            #expect(d1 >= 2.0 && d1 <= 4.0)
        }
    }

    @Test("equal jitter respects maxDelay cap")
    func equalJitterCapped() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 3.0, jitter: .equal)
        for _ in 0..<100 {
            let d = policy.delay(forAttempt: 10, previousDelay: 3.0)
            #expect(d >= 1.5 && d <= 3.0)
        }
    }

    @Test("decorrelated jitter uses previous delay to widen range")
    func decorrelatedJitter() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 60.0, jitter: .decorrelated)
        for _ in 0..<100 {
            // previousDelay = 2.0 → range [1.0...6.0]
            let d = policy.delay(forAttempt: 1, previousDelay: 2.0)
            #expect(d >= 1.0 && d <= 6.0)
        }
    }

    @Test("decorrelated jitter respects maxDelay cap")
    func decorrelatedJitterCapped() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 5.0, jitter: .decorrelated)
        for _ in 0..<100 {
            // previousDelay = 10.0 → upper = min(5.0, 30.0) = 5.0
            let d = policy.delay(forAttempt: 3, previousDelay: 10.0)
            #expect(d >= 1.0 && d <= 5.0)
        }
    }

    @Test("decorrelated jitter falls back to baseDelay when previous is small")
    func decorrelatedJitterSmallPrevious() {
        let policy = RetryPolicy(baseDelay: 1.0, maxDelay: 60.0, jitter: .decorrelated)
        for _ in 0..<100 {
            // previousDelay = 0.1 → upper = 0.3, max(1.0, 0.3) = 1.0 → range [1.0...1.0]
            let d = policy.delay(forAttempt: 0, previousDelay: 0.1)
            #expect(d == 1.0)
        }
    }
}

