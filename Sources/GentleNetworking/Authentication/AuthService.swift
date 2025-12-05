//  Jonathan Ritchey
import Foundation

public protocol AuthServiceProtocol {
    var headerField: String { get }
    var headerValuePrefix: String { get }
    var keyChainKey: String { get }
    var keyChainStore: KeyChainStoreProtocol { get }
    
    func loadAccessToken() throws -> String?
    func saveAccessToken(_ token: String) throws
    func authorize(_ request: URLRequest) throws -> URLRequest
    func deleteAccessToken() throws
}

public extension AuthServiceProtocol {
    var headerField: String { "Authorization" }
    var headerValuePrefix: String { "Bearer " }
    var keyChainKey: String { "accessToken" }
    func loadAccessToken() throws -> String? {
        return try? keyChainStore.value(forKey: keyChainKey)
    }
    func saveAccessToken(_ token: String) throws {
        try keyChainStore.save(token, forKey: keyChainKey)
    }
    func authorize(_ request: URLRequest) throws -> URLRequest {
        var copy = request
        if let token = try loadAccessToken() {
            copy.setValue("\(headerValuePrefix)\(token)", forHTTPHeaderField: headerField)
        }
        return copy
    }
    func deleteAccessToken() throws {
        try keyChainStore.deleteValue(forKey: keyChainKey)
    }
}

public struct DefaultAuthService: AuthServiceProtocol {
    public let keyChainStore: any KeyChainStoreProtocol = SystemKeyChainStore()
    public init() {
    }
}
