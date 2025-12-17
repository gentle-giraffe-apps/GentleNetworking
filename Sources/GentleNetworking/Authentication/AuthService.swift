//  Jonathan Ritchey
import Foundation

public protocol AuthServiceProtocol: Sendable {
    var headerField: String { get }
    var headerValuePrefix: String { get }
    var keyChainKey: String { get }
    var keyChainStore: KeyChainStoreProtocol { get }
    
    func loadAccessToken() async throws -> String?
    func saveAccessToken(_ token: String) async throws
    func authorize(_ request: URLRequest) async throws -> URLRequest
    func deleteAccessToken() async throws
}

public extension AuthServiceProtocol {
    var headerField: String { "Authorization" }
    var headerValuePrefix: String { "Bearer " }
    var keyChainKey: String { "accessToken" }
    func loadAccessToken() async throws -> String? {
        return try? await keyChainStore.value(forKey: keyChainKey)
    }
    func saveAccessToken(_ token: String) async throws {
        try await keyChainStore.save(token, forKey: keyChainKey)
    }
    func authorize(_ request: URLRequest) async throws -> URLRequest {
        var copy = request
        if let token = try await loadAccessToken() {
            copy.setValue("\(headerValuePrefix)\(token)", forHTTPHeaderField: headerField)
        }
        return copy
    }
    func deleteAccessToken() async throws {
        try await keyChainStore.deleteValue(forKey: keyChainKey)
    }
}
